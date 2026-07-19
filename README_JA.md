# MediaHarbor

[简体中文](README.md) | [English](README_EN.md) | [繁體中文](README_ZH-HANT.md) | 日本語

MediaHarbor は、[yt-dlp](https://github.com/yt-dlp/yt-dlp) を基盤に開発されたモダンなmacOSネイティブメディアダウンローダーです。SwiftUIで一から構築され、フォーマット選択、音声抽出、プレイリスト、字幕、メタデータ、SponsorBlock、ブラウザCookie、ダウンロードキュー、進捗表示、ローカル履歴に対応しています。

[最新リリースをダウンロード](https://github.com/jason312928/MediaHarbor/releases/latest) · [yt-dlp対応サイトを見る](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md)

## 主な機能

- macOS 14以降に対応したネイティブSwiftUIインターフェース
- macOS 26ではLiquid Glass、以前のバージョンではシステム素材を使用
- 狭いウインドウでコンテンツとサイドバーを自動的に再配置
- 英語、簡体字中国語、繁体字中国語、日本語を即時切り替え
- yt-dlpが対応する幅広いメディアサイトをサポート
- 公式`yt-dlp_macos`をオンデマンドでインストール・更新
- URLのドラッグ＆ドロップ、クリップボード解析、ショートカット、メニューバー進捗、Finder表示
- 画質選択、音声のみ、プレイリスト、字幕、メタデータ、ブラウザCookie、SponsorBlock
- 進捗、速度、ETA、キャンセル、通知、ローカル履歴を備えたダウンロードキュー
- アカウント、広告、分析、トラッキングなし

## 動作要件

- macOS 14 Sonoma以降
- ソースからのビルドにはSwift 6ツールチェーン
- 結合と後処理にはFFmpeg。Homebrewでは`brew install ffmpeg`を実行

MediaHarborはユーザーがインストールを選択したときに、yt-dlp公式GitHub Releaseから実行ファイルをダウンロードし、次の場所に保存します。

```text
~/Library/Application Support/MediaHarbor/Tools/yt-dlp
```

## ビルドと実行

```bash
git clone https://github.com/jason312928/MediaHarbor.git
cd MediaHarbor
./script/build_and_run.sh
```

```bash
swift build
./script/test.sh
./script/build_and_run.sh --verify
MEDIAHARBOR_VERSION=1.0.0 ./script/build_and_run.sh --package
```

パッケージモードは、現在のアーキテクチャ向けのバージョン付きDMGとZIPを`dist/`に作成します。

## プロジェクト構成

```text
Sources/MediaHarbor/
├── App/          アプリのエントリ、シーン、メニュー
├── Models/       メディアとダウンロードのデータモデル
├── Services/     yt-dlpのインストール、引数構築、プロセス実行
├── Stores/       アプリ状態、ダウンロードキュー、ローカル履歴
├── Support/      多言語、書式、自動チェック、ビジュアルスタイル
└── Views/        SwiftUI機能画面と再利用可能なコンポーネント
Documentation/    アーキテクチャとリリース文書
Legacy/           以前のPython実装と移行参考素材
script/           ビルド、実行、テスト、パッケージスクリプト
```

データフローと拡張ポイントは[Documentation/ARCHITECTURE.md](Documentation/ARCHITECTURE.md)を参照してください。ダウンロード機能は独立した`DownloadArgumentContributor`として構成されるため、プロキシ、速度制限、チャプター分割をプロセス実行部分から分離できます。

## 法令を守った利用

アクセス権限のあるメディアのみをダウンロードし、サイトの利用規約、著作権法、地域の法令に従ってください。MediaHarborはDRMを回避せず、yt-dlpや対応サイトとは提携していません。

## 謝辞

- [yt-dlp](https://github.com/yt-dlp/yt-dlp)はMediaHarborの中心となるメディア解析・ダウンロードエンジンです。
- 本プロジェクトは初期に[bytePatrol/YT-DLP-GUI-for-MacOS](https://github.com/bytePatrol/YT-DLP-GUI-for-MacOS)から一部着想を得た後、新しいアーキテクチャとより広い目的を持つ独立したSwiftUIアプリへ発展しました。
- [SponsorBlock](https://sponsor.ajay.app/)はオプションの区間削除機能にコミュニティデータを提供します。

## ライセンス

MIT。詳細は[LICENSE](LICENSE)をご覧ください。
