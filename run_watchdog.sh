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

# 0=配信済み / 1=未配信 / 2=判定不能（GitHubに到達できない）
# 「通信できない」を「未配信」と断定しないこと。2026-09-19に一時的な通信断で
# 配信済みの日に復旧が走り、誤って「配信できていません」と通知した。
published() {
  local body
  body=$(curl -sf --max-time 30 \
    "https://api.github.com/repos/jamstyle2007-dev/test-news-data/contents/daily.json?ref=main" \
    -H "Accept: application/vnd.github.raw") || return 2
  [ -n "$body" ] || return 2
  printf '%s' "$body" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(2)
sys.exit(0 if any(i['date'] == '$TODAY' for i in d['entries']) else 1)"
}

STATE=0; published || STATE=$?
if [ "$STATE" = "2" ]; then
  # 通信が無ければ記事の生成自体ができないので、ここで騒がず次の見張りに委ねる
  echo "GitHubに到達できず判定不能。復旧は行わない（次回の見張りで再確認）"
  exit 0
fi

if [ "$STATE" = "0" ]; then
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
  published && { OK_PUB=0; break; }
  OK_PUB=$?
  sleep 10
done

if [ "$OK_PUB" = "2" ]; then
  # 通信不可では確認も生成もできない。誤警報を出さず次回の見張りに委ねる
  echo "通信不可で確認できない。通知せず終了（次回の見張りで再確認）"
  exit 0
fi

if [ "$OK_PUB" = "0" ]; then
  echo "復旧成功"
  notify "復旧成功: 本日分を配信しました（$TODAY）"
else
  echo "復旧失敗"
  notify "配信できていません（$TODAY）。ログ: test-news-data/logs"
fi
