# emoji-test.txt + CLDR annotations -> JSON list of
# {e: emoji, n: name, g: group, k: keywords, v: [{e, n}] skin-tone variants}.
import json
import re
import sys
import xml.etree.ElementTree as ET

test_file, annotation_files, out = sys.argv[1], sys.argv[2:-1], sys.argv[-1]

keywords = {}
for path in annotation_files:
    for a in ET.parse(path).iter("annotation"):
        if a.get("type") != "tts" and a.text:
            keywords.setdefault(a.get("cp"), [k.strip() for k in a.text.split("|")])

line_re = re.compile(r"^[0-9A-F ]+;\s*fully-qualified\s*#\s*(\S+)\s+E\S+\s+(.+)$")
emoji, by_name, group = [], {}, ""
for line in open(test_file, encoding="utf-8"):
    if line.startswith("# group: "):
        group = line[9:].strip()
        continue
    m = line_re.match(line)
    if not m or group == "Component":
        continue
    char, name = m.groups()
    base, _, tone = name.partition(": ")
    if "skin tone" in tone and base in by_name:
        by_name[base]["v"].append({"e": char, "n": tone})
        continue
    entry = {
        "e": char,
        "n": name,
        "g": group,
        "k": keywords.get(char) or keywords.get(char.replace("️", ""), []),
        "v": [],
    }
    by_name[name] = entry
    emoji.append(entry)

with open(out, "w", encoding="utf-8") as f:
    json.dump(emoji, f, ensure_ascii=False, separators=(",", ":"))
