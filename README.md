# test-news-data

iOSアプリ「テストに出るニュース」の配信データ（毎朝1本の時事エントリ）。

- `daily.json` — 全配信アーカイブ。アプリが起動時に取得して内蔵分とマージする
- `run_morning.sh` — 毎朝5:40の自動生成（launchd: com.jack.testnews.morning）
- `run_watchdog.sh` — 毎朝7:10の配信見張り（launchd: com.jack.testnews.watchdog）
- `tools/validate.py` — スキーマ・表記ルール検証／`tools/fallback.py` — 予備エントリ配信
