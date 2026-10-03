# 花嫁もぐもぐチャレンジ！

結婚式の待ち時間に、ゲストがスマートフォンで遊ぶミニゲームです。

ブランコ（二重振り子）に乗ってゆらゆら揺れる新婦に向けて、新郎が食べ物を投げ、口元に届けて食べさせます。制限時間 20 秒で、どれだけ高い得点を取れるかを競います。新婦の好物ほど高得点で、続けて食べさせると連続ボーナスが付きます。

公開先: https://chromiumly.github.io/pendulum_feeding_game/ （横向きで遊ぶ Web アプリ）

## 主な機能

- **二重振り子で動く新婦**: 遊ぶ前に振り子の位置を決め、スタートすると予測しにくい動きで揺れ続ける
- **ドラッグで投げる**: 引っぱった方向と反対向きに飛ぶパチンコ式。引っぱる間は予測軌道を表示
- **制限時間内のスコアアタック**: 20 秒。好物ほど高得点、連続で食べさせると倍率アップ
- **プレイヤー ID**: QR コードで配る URL に ID が入っていて、その ID でスコアを記録する（ID なしはゲスト）
- **スコアランキング**: 全試行中の順位と、挑戦者中の自己ベストの順位をリザルトで表示。遊んだ回数が多いほど好物が出やすくなるプレイ回数ボーナスもある
- **Firebase によるスコア管理**: Cloud Firestore に記録し、書き込みの正しさはセキュリティルールで保証。通信できないときは端末に残して後で送る
- **GitHub Pages で Web 公開**: `main` へのプッシュで自動ビルド・公開

## Documentation

| ドキュメント | 内容 |
|---|---|
| [ゲームデザイン](docs/game-design.md) | 画面の流れ、操作、ルール、演出 |
| [得点と抽選](docs/scoring.md) | 好物の点数、連続ボーナス、遊んだ回数による食べ物の出やすさ |
| [物理](docs/physics.md) | 二重振り子のモデルと数値積分、食べ物の飛行、当たり判定 |
| [アーキテクチャ](docs/architecture.md) | コードの構成と責務、ゲームの状態と描画の分け方、テスト |
| [Firebase](docs/firebase.md) | プレイヤー ID、Firestore のデータ構成とルール、管理ツール |
| [デプロイ](docs/deployment.md) | GitHub Pages への公開、ルールとの順番、本番前の準備 |
| [アセット](docs/assets.md) | 画像・アイコン・フォントの置き場所と作り方 |

## Development

### 必要なもの

- Flutter 3.47.5（stable）と、同梱の Dart（`pubspec.yaml` の SDK 制約は `^3.13.4`）
- Chrome（Web で動かすため）
- 必要に応じて:
  - Firestore のルールのテスト: Node.js と Java（[firebase.md](docs/firebase.md#セキュリティルールのテストと反映)）
  - プレイヤー ID の登録など: Firebase のサービスアカウントの鍵（[firebase.md](docs/firebase.md#管理ツール)）

### 起動

```bash
flutter pub get
flutter run -d chrome
```

- そのままではゲスト（記録なし）で起動する。ID 付きで試すときは、開いた URL の末尾に `?id=<登録済みの ID>` を付けて読み込み直す。
- 当たり判定の円を表示する: `flutter run -d chrome --dart-define=SHOW_HIT_CIRCLES=true`

### テストと静的解析

```bash
flutter analyze
flutter test
```

### ビルド

```bash
flutter build web --release --base-href /pendulum_feeding_game/
```

GitHub Pages への公開は CI が行う（[deployment.md](docs/deployment.md)）。

## Tech Stack

| 分野 | 使用しているもの |
|---|---|
| アプリ | Flutter（Web）、Dart |
| ゲームエンジン | Flame（ゲームループ、描画、入力） |
| UI | flutter_svg（Figma から書き出したアイコン） |
| バックエンド | Firebase（Cloud Firestore、セキュリティルール）、crypto（自己ベストのキーの SHA-256） |
| 端末への保存 | shared_preferences |
| 公開 | GitHub Pages、GitHub Actions |
| 開発用 | fake_cloud_firestore（テスト）、Firebase エミュレータ（ルールのテスト）、image（画像の縮小）、qr・googleapis_auth（プレイヤー ID の管理ツール） |
