case "${1:-list}" in
  list) exec cliphist list ;;
  copy)
    [ $# -ge 2 ] || { echo "usage: nyx-clipboard copy <id>" >&2; exit 2; }
    printf '%s\t' "$2" | cliphist decode | wl-copy ;;
  delete)
    [ $# -ge 2 ] || { echo "usage: nyx-clipboard delete <id>" >&2; exit 2; }
    printf '%s\t' "$2" | cliphist delete ;;
  wipe) exec cliphist wipe ;;
  *)
    echo "usage: nyx-clipboard {list|copy <id>|delete <id>|wipe}" >&2
    exit 2 ;;
esac
