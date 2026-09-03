#!/bin/bash
# daily.json を GitHub(main) へ公開する
set -u
cd "$(dirname "$0")"
MSG="${1:-Auto publish $(date +%F)}"
python3 -c "import json; json.load(open('daily.json'))" || { echo "publish中止: daily.jsonが壊れている"; exit 1; }
git add daily.json spare_pool.json 2>/dev/null
git commit -m "$MSG" >/dev/null 2>&1
for i in 1 2 3; do
  git push origin main && exit 0
  echo "push失敗（$i回目）"
  # 待機機(2台目Mac)が先にpushしているとリモートが進んで弾かれる。これは再試行では
  # 解消しないので取り込んでから押し直す。通信断など一時的な失敗ならpullも失敗し、
  # 従来どおり待って再試行になる。
  if git pull --rebase --autostash --quiet origin main; then
    echo "リモートの更新を取り込んだ。すぐ押し直す"
  else
    echo "20秒後に再試行"
    sleep 20
  fi
done
exit 1
