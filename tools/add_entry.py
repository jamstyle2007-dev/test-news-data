#!/usr/bin/env python3
"""draft_today.json を daily.json に追加（同じ日付/idがあれば置き換えない=先勝ち）。"""
import json, sys

draft = json.load(open(sys.argv[1] if len(sys.argv) > 1 else "draft_today.json", encoding="utf-8"))
data = json.load(open("daily.json", encoding="utf-8"))

if any(x["date"] == draft["date"] or x["id"] == draft["id"] for x in data["entries"]):
    print("SKIP: その日付/idのエントリは既にある")
    sys.exit(0)

data["entries"].append(draft)
data["entries"].sort(key=lambda x: x["date"])
with open("daily.json", "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
print(f"ADDED: {draft['id']} {draft['date']} {draft['title']}")
