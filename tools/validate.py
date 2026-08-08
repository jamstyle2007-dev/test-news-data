#!/usr/bin/env python3
"""draft_today.json の検証器。エラーは全部列挙して非0で終了（再生成時にAIへフィードバックされる）。
usage: validate.py draft_today.json [expected_date]
"""
import json, sys, re, os

CATS = {"経済", "金融", "政治", "国際", "暮らし"}
# 幼児向け平仮名の禁止語（中高生向け表記ルール・過去にJACKから3回指摘）
BANNED = ["きょうの", "せいかい", "ざんねん", "つぎへ", "にがて", "えらぶ", "まちがえた",
          "もういちど", "むりょう", "むせいげん", "かんたんな", "すえおき", "こたえよう"]

def fail(msgs):
    for m in msgs:
        print("NG:", m)
    sys.exit(1)

path = sys.argv[1] if len(sys.argv) > 1 else "draft_today.json"
expected_date = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("TN_DATE", "")

errs = []
try:
    e = json.load(open(path, encoding="utf-8"))
except Exception as ex:
    fail([f"JSONとして読めない: {ex}"])

for k in ["id", "date", "cat", "title", "what", "why", "jack", "quiz", "term"]:
    if k not in e:
        errs.append(f"キー {k} が無い")
if errs:
    fail(errs)

if not re.match(r"^d\d{8}$", e["id"]):
    errs.append(f"idは d+YYYYMMDD 形式（現在: {e['id']}）")
if not re.match(r"^\d{4}-\d{2}-\d{2}$", e["date"]):
    errs.append(f"dateは YYYY-MM-DD 形式（現在: {e['date']}）")
if expected_date and e["date"] != expected_date:
    errs.append(f"dateが {expected_date} でない（現在: {e['date']}）")
if e["id"] != "d" + e["date"].replace("-", ""):
    errs.append("idとdateが一致していない")
if e["cat"] not in CATS:
    errs.append(f"catは {CATS} のどれか（現在: {e['cat']}）")
if not (6 <= len(e["title"]) <= 30):
    errs.append(f"titleは6〜30字（現在: {len(e['title'])}字）")
if not (90 <= len(e["what"]) <= 220):
    errs.append(f"whatは90〜220字（現在: {len(e['what'])}字）")
if not (60 <= len(e["why"]) <= 190):
    errs.append(f"whyは60〜190字（現在: {len(e['why'])}字）")
if not (40 <= len(e["jack"]) <= 220):
    errs.append(f"jackは40〜220字（現在: {len(e['jack'])}字）")
if "私" not in e["jack"] and "俺" in e["jack"]:
    errs.append("jackの一人称は「私」（「俺」は禁止）")
if "俺" in e["jack"]:
    errs.append("jackに「俺」が含まれる（一人称は「私」）")

q = e["quiz"]
for k in ["q", "c", "a", "e"]:
    if k not in q:
        errs.append(f"quizにキー {k} が無い")
if isinstance(q.get("c"), list):
    if len(q["c"]) != 4:
        errs.append(f"quiz.cは4択（現在: {len(q['c'])}）")
    if len(set(q["c"])) != len(q["c"]):
        errs.append("quiz.cに重複した選択肢がある")
if not isinstance(q.get("a"), int) or not (0 <= q.get("a", -1) <= 3):
    errs.append("quiz.aは0〜3の整数")
if not q.get("e"):
    errs.append("quiz.e（解説）が空")

t = e["term"]
if not t.get("name") or not t.get("def"):
    errs.append("termのnameまたはdefが空")

joined = e["title"] + e["what"] + e["why"] + e["jack"] + q.get("q", "") + "".join(q.get("c", [])) + q.get("e", "")
for w in BANNED:
    if w in joined:
        errs.append(f"幼児向け平仮名の禁止語「{w}」が含まれる（漢字で書く）")
if "公共, 政治" in joined or "公共,政治" in joined:
    errs.append("科目名は「公共，政治・経済」（全角読点）で書く")

if errs:
    fail(errs)
print("OK: 検証合格")
