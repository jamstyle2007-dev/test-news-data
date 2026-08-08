#!/usr/bin/env python3
"""生成失敗時の最終手段: spare_pool.json から未使用の予備エントリを今日の日付で配信する。
（配信の信用第一: 検証NGでも止めず、必ず何かを出す）
usage: fallback.py <YYYY-MM-DD>
"""
import json, sys

date = sys.argv[1]
pool = json.load(open("spare_pool.json", encoding="utf-8"))
spare = next((s for s in pool["spares"] if not s.get("used")), None)
if not spare:
    print("NG: 予備エントリが尽きた")
    sys.exit(1)

entry = {k: v for k, v in spare.items() if k != "used"}
entry["id"] = "d" + date.replace("-", "")
entry["date"] = date

data = json.load(open("daily.json", encoding="utf-8"))
if any(x["date"] == date for x in data["entries"]):
    print("SKIP: 本日分は既にある")
    sys.exit(0)
data["entries"].append(entry)
data["entries"].sort(key=lambda x: x["date"])
with open("daily.json", "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, separators=(",", ":"))

spare["used"] = date
with open("spare_pool.json", "w", encoding="utf-8") as f:
    json.dump(pool, f, ensure_ascii=False, indent=1)
print(f"FALLBACK_ADDED: {entry['id']} {entry['title']}")
