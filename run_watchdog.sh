#!/bin/bash
# テストに出るニュース 配信見張り（毎朝7:10）
# 本日分がGitHub本体(main)に公開済みかを確認し、未配信なら run_morning を再実行して復旧する。
set -u
cd "$(dirname "$0")"
mkdir -p logs
LOG="logs/watchdog-$(date +%F).log"
exec >> "$LOG" 2>&1
echo "===== run_watchdog $(date '+%F %T') ====="

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
TODAY=$(date +%F)

# 待機モード（2台目のMac用）: 判断前に必ずリモート最新へ同期する
if [ "${TN_STANDBY:-0}" = "1" ]; then
  git fetch origin main --quiet && git reset --hard origin/main --quiet
fi

# パイロット期間（内蔵7本: 〜2026-08-13）は配信不要
if [[ "$TODAY" < "2026-08-14" ]]; then
  echo "パイロット期間中（$TODAY）。見張り不要"
  exit 0
fi

notify() {
  osascript -e "display notification \"$1\" with title \"テストに出るニュース 見張り\" sound name \"Basso\"" 2>/dev/null || true
}

published() {
  curl -s --max-time 30 \
    "https://api.github.com/repos/jamstyle2007-dev/test-news-data/contents/daily.json?ref=main" \
    -H "Accept: application/vnd.github.raw" \
  | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    ok = any(i['date'] == '$TODAY' for i in d['entries'])
except Exception:
    ok = False
sys.exit(0 if ok else 1)"
}

if published; then
  echo "本日分($TODAY)は配信済み。OK"
  exit 0
fi

echo "未配信を検知。run_morning を再実行"
./run_morning.sh

# push直後のGitHub APIは数秒だけ古い値を返すことがある。単発で判定すると
# 配信できているのに「配信できていません」と誤通知するため、10秒おきに3回確かめる
# （Money Flash側で2026-09-04に同種の誤検知が発生）。
OK_PUB=1
for _ in 1 2 3; do
  if published; then OK_PUB=0; break; fi
  sleep 10
done

if [ "$OK_PUB" = "0" ]; then
  echo "復旧成功"
  notify "復旧成功: 本日分を配信しました（$TODAY）"
else
  echo "復旧失敗"
  notify "配信できていません（$TODAY）。ログ: test-news-data/logs"
fi
