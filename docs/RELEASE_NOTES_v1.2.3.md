## Media Downloader v1.2.3 試用版

### 今回の更新

- 「最高画質（8K）」など、取得できた最大解像度を正しく表示します。4Kを超える解像度を一律4Kと表示していた問題を修正しました。
- 4320pは8K、それ以外の高解像度は5760p・8640pなどの数値で表示します。画質メニュー、解像度案内、変換前の確認表示を統一しました。
- YouTubeのログイン確認エラーを日本語・英語で案内し、本人が選んだ場合だけChrome・Safari・Firefoxのログイン状態で一度再試行できます。通常のダウンロードではブラウザのCookieを読みません。

「最高画質」には4Kの上限を設けていません。ただし、配信元の提供形式やMacの性能によって、取得・変換できる解像度は異なります。あらゆる解像度の変換を保証するものではありません。

### ダウンロード

- M1・M2・M3・M4以降のMac: `Media-Downloader-1.2.3-Apple-Silicon.dmg`
- Intel Mac: `Media-Downloader-1.2.3-Intel.dmg`

macOS Monterey 12以降に対応します。DMG内の `Manuals` フォルダには、そのまま使用できる日英の初回起動ガイド（v1.2.2版）を同梱しています。

内蔵ツールはyt-dlp 2026.08.19とFFmpeg 7.1です。追加インストールは不要です。

Apple Developer IDでの署名・公証前の試用版です。初回起動時の警告については同梱ガイドをご確認ください。Intel Monterey実機での動作確認は未完了です。

ブラウザ再試行ではyt-dlpが選択したブラウザのCookieを読み取ります。アプリはCookieを保存しません。成功は保証されず、YouTubeアカウントへの制限などのリスクがあります。Cookieや認証情報を他人に送らないでください。詳しくは[yt-dlp公式案内](https://github.com/yt-dlp/yt-dlp/wiki/Extractors#exporting-youtube-cookies)をご確認ください。

---

## English

Version 1.2.3 fixes resolution labels above 4K. Detected 4320p sources now show
**Best quality (8K)**. Other higher resolutions retain their numeric labels,
such as 5760p or 8640p. Quality menus, resolution notices, and conversion
confirmations use consistent labels. Best-quality downloads remain uncapped;
availability and successful conversion depend on the source and the Mac.

YouTube verification failures now have clearer Japanese/English guidance and
an optional, one-time retry using a selected signed-in Chrome, Safari, or
Firefox browser. Normal downloads do not read browser cookies. The app does
not save cookies; account use carries risk and does not guarantee success.

Choose the Apple Silicon DMG for M-series Macs or the Intel DMG for Intel Macs.
Requires macOS Monterey 12 or later. Both DMGs include the unchanged v1.2.2
Japanese/English first-launch guides in `Manuals`. Bundled tools remain
yt-dlp 2026.08.19 and FFmpeg 7.1. This trial build is ad-hoc signed and not
notarized. Physical Intel Monterey testing remains outstanding.
