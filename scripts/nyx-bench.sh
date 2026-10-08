# Samples the running shell's CPU, memory and wakeups, idle and with each panel open.
usage() {
  echo "usage: nyx-bench [--secs N] [--json] [--forks] {all|idle|playing|<panel>}" >&2
  echo "panels: sys wifi clipboard docker tailnet bitwarden" >&2
  exit 2
}

secs=${NYX_BENCH_SECS:-20}
json=0
forks=0
while [ $# -gt 0 ]; do
  case "$1" in
    --secs) [ $# -ge 2 ] || usage; secs=$2; shift 2 ;;
    --json) json=1; shift ;;
    --forks) forks=1; shift ;;
    -h|--help) usage ;;
    *) break ;;
  esac
done
[ $# -eq 1 ] || usage
target=$1

declare -A shortcut=(
  [sys]=toggleSystem [wifi]=toggleWifi [clipboard]=toggleClipboard
  [docker]=toggleDocker [tailnet]=toggleTailnet [bitwarden]=toggleBitwarden
)
panels=(sys wifi clipboard docker tailnet bitwarden)
case "$target" in
  all|idle|playing) ;;
  *) [ -n "${shortcut[$target]:-}" ] || usage ;;
esac

# The shell is the quickshell wrapper whose command line names nyx.
find_pid() {
  if [ -n "${NYX_BENCH_PID:-}" ]; then echo "$NYX_BENCH_PID"; return; fi
  local pid
  for pid in $(pgrep -x '.quickshell-wra' || true); do
    if tr '\0' ' ' < "/proc/$pid/cmdline" | grep -q nyx; then echo "$pid"; return; fi
  done
  echo "nyx-bench: nyx shell not running" >&2
  exit 1
}
pid=$(find_pid)
hz=$(getconf CLK_TCK)

# Own plus reaped children's CPU ticks, so short-lived forks are counted.
cpu_ticks() {
  awk '{ print $14 + $15 + $16 + $17 }' "/proc/$pid/stat"
}

# Voluntary context switches over all threads, a proxy for wakeups.
wakeups() {
  cat /proc/"$pid"/task/*/status 2>/dev/null | awk '/^voluntary_ctxt_switches/ { n += $2 } END { print n + 0 }'
}

status_field() {
  awk -v k="$1:" '$1 == k { print $2 }' "/proc/$pid/status"
}

toggle() {
  hyprctl dispatch "hl.dsp.global(\"nyx:${shortcut[$1]}\")" > /dev/null
}

# One row: name, cpu %, rss MB, threads, wakeups/s, execs/s (or -).
measure() {
  local name=$1 t0 t1 w0 w1 e="-" strace_pid="" log=""
  if [ "$forks" = 1 ]; then
    log=$(mktemp)
    strace -f -qq -e trace=execve -p "$pid" -o "$log" &
    strace_pid=$!
  fi
  t0=$(cpu_ticks); w0=$(wakeups)
  sleep "$secs"
  t1=$(cpu_ticks); w1=$(wakeups)
  if [ -n "$strace_pid" ]; then
    kill "$strace_pid" 2>/dev/null || true
    wait "$strace_pid" 2>/dev/null || true
    e=$(awk -v s="$secs" '/execve\(/ { n++ } END { printf "%.2f", n / s }' "$log")
    rm -f "$log"
  fi
  awk -v n="$name" -v t0="$t0" -v t1="$t1" -v w0="$w0" -v w1="$w1" -v s="$secs" -v hz="$hz" \
      -v rss="$(status_field VmRSS)" -v th="$(status_field Threads)" -v e="$e" \
    'BEGIN { printf "%s\t%.2f\t%.1f\t%d\t%.1f\t%s\n", n, (t1 - t0) / hz / s * 100, rss / 1024, th, (w1 - w0) / s, e }'
}

run_panel() {
  toggle "$1"
  sleep 2
  measure "$1"
  toggle "$1"
  sleep 1
}

rows=$(mktemp)
trap 'rm -f "$rows"' EXIT
case "$target" in
  all)
    measure idle >> "$rows"
    for p in "${panels[@]}"; do run_panel "$p" >> "$rows"; done ;;
  idle|playing) measure "$target" >> "$rows" ;;
  *) run_panel "$target" >> "$rows" ;;
esac

if [ "$json" = 1 ]; then
  jq -Rn '[inputs | split("\t") | {
    scenario: .[0], cpu_percent: (.[1] | tonumber), rss_mb: (.[2] | tonumber),
    threads: (.[3] | tonumber), wakeups_per_s: (.[4] | tonumber),
    execs_per_s: (.[5] | if . == "-" then null else tonumber end)
  }]' < "$rows"
else
  { printf 'scenario\tcpu%%\trss_mb\tthreads\twakeups/s\texecs/s\n'; cat "$rows"; } | column -t -s "$(printf '\t')"
fi

# Idle is the budget that matters; panels are allowed to cost more while open.
max_cpu=${NYX_BENCH_MAX_IDLE_CPU:-1.0}
idle_cpu=$(awk -F'\t' '$1 == "idle" { print $2 }' "$rows")
if [ -n "$idle_cpu" ] && awk -v c="$idle_cpu" -v m="$max_cpu" 'BEGIN { exit !(c > m) }'; then
  echo "nyx-bench: idle cpu ${idle_cpu}% over the ${max_cpu}% budget" >&2
  exit 1
fi
