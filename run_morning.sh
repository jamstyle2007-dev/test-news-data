#!/bin/bash
# テストに出るニュース 毎朝の完全自動配信（Money Flash方式）
# 方針: 配信の信用第一。生成→検証→再生成→予備エントリ の多段リカバリで必ず出す。
# 構造破損（アプリが読めないJSON）だけは公開しない（publish.shが弾く）。
set -u
cd "$(dirname "$0")"
mkdir -p logs
LOG="logs/$(date +%F).log"
exec >> "$LOG" 2>&1
echo "===== run_morning $(date '+%F %T') ====="

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
TODAY="${TN_DATE:-$(date +%F)}"

notify() {
  osascript -e "display notification \"$1\" with title \"テストに出るニュース 配信\" sound name \"Basso\"" 2>/dev/null || true
}

# 本日分が既にあるか
have_today() {
  python3 - <<EOF
import json, sys
data = json.load(open("daily.json"))
sys.exit(0 if any(i["date"] == "$TODAY" for i in data["entries"]) else 1)
EOF
}

if have_today; then
  if git diff --quiet HEAD -- daily.json 2>/dev/null; then
    echo "本日分($TODAY)は公開済み。終了"
  else
    echo "本日分はローカルにあるが未push。publishをリトライ"
    ./publish.sh "Auto publish $TODAY (retry)" && echo "公開完了(リトライ)" || notify "push失敗（$TODAY）。手動確認を"
  fi
  exit 0
fi

# 生成→検証→追加を最大2回試行（2回目は検証エラーをAIへフィードバック）
ERRFILE="/tmp/tn_gen_err.txt"
ADDED=0
for ATTEMPT in 1 2; do
  echo "--- 生成試行 $ATTEMPT ---"
  rm -f draft_today.json

  PROMPT="$(cat MORNING_PROMPT.md)"
  if [ "$ATTEMPT" = "2" ] && [ -s "$ERRFILE" ]; then
    PROMPT="$PROMPT

【重要】前回の生成は以下の検証エラーで失敗した。同じ誤りを繰り返さないこと:
$(cat "$ERRFILE")"
  fi

  TN_DATE="$TODAY" claude -p "$PROMPT" \
    --allowedTools "WebSearch" "WebFetch" "Read" "Write" "Bash(date:*)" "Bash(python3 tools/validate.py:*)" \
    --max-turns 40
  echo "claude exit: $?"

  if [ ! -f draft_today.json ]; then
    echo "draft_today.json が無い（試行$ATTEMPT）"
    echo "ドラフトファイルが生成されなかった" > "$ERRFILE"
    continue
  fi

  if TN_DATE="$TODAY" python3 tools/validate.py draft_today.json "$TODAY" > "$ERRFILE" 2>&1; then
    python3 tools/add_entry.py draft_today.json && ADDED=1 && break
  else
    echo "検証NG（試行$ATTEMPT）:"; cat "$ERRFILE"
  fi
done

# 最終手段: 予備エントリで必ず配信
if [ "$ADDED" != "1" ]; then
  echo "--- 予備エントリにフォールバック ---"
  if python3 tools/fallback.py "$TODAY"; then
    ADDED=1
    notify "生成失敗のため予備問題で配信（$TODAY）。ログ確認を"
  fi
fi

if [ "$ADDED" = "1" ]; then
  if ./publish.sh "Auto publish $TODAY"; then
    echo "公開完了($TODAY)"
  else
    notify "push失敗（$TODAY）。見張りが7:10に再試行します"
  fi
else
  notify "配信生成が完全に失敗（$TODAY）。予備も尽きています"
fi
rm -f draft_today.json
