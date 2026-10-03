# アーキテクチャ

コードの構成と、各部分の責務。物理・ゲームのルール・描画・UI・ランキングを分け、物理とルールは Flutter や Flame に依存しない純粋な Dart にしている。

## ディレクトリ

| パス | 責務 |
|---|---|
| `lib/physics/` | 二重振り子の運動方程式、RK4、力学的エネルギー |
| `lib/math/` | 2D ベクトル（`Vec2`） |
| `lib/game/model/` | ゲームの状態とルール。`GameSession`（1 回のプレイ）、`GameConfig`（調整値と食べ物の一覧）、ルールの純粋関数（`rules.dart`、`setup_rules.dart`）、イベント |
| `lib/game/fixed_step_clock.dart` | フレーム時間を固定ステップの回数に変換する |
| `lib/game/flame/` | Flame によるゲームの実行と描画。`PendulumFeedingGame` と各コンポーネント（振り子、新婦、新郎、食べ物、軌道ガイド、HUD、入力、得点演出） |
| `lib/app/` | Flutter の画面（タイトル、ゲーム、遊び方、リザルト、カウントダウンなど） |
| `lib/ui/` | 色、文字スタイル、アセットのパス、表示用の書式、共通ウィジェット |
| `lib/ranking/` | プレイヤー ID、記録とランキング、Firebase との接続 |
| `assets/` | ゲームに同梱する画像・アイコン・フォント（[assets.md](assets.md)） |
| `art/` | 画像の元データ。`tool/images.dart` で `assets/images/` を作る |
| `tool/` | 開発用スクリプト（画像の作成、プレイヤー ID の管理、Firestore ルールのテスト、TS 版との比較データ作成） |
| `test/` | 単体テストとウィジェットテスト |

## ゲームの中心: `GameSession`

`lib/game/model/game_session.dart` の `GameSession` が、1 回のプレイの状態（フェーズ、振り子、食べ物、狙い、得点、連続数、経過時間）をすべて持つ。

- `step()` を呼ぶたびに 1/60 秒だけ進む。実時間・Flame・描画のことは知らない。
- 入力はメソッドで受け取る（`beginPlacement` / `updatePlacement` / `startCountdown` / `beginAim` / `updateAim` / `releaseAim` など）。座標はワールド座標（px）。
- 表示のためのきっかけ（食べた、投げた、外れた、終わった）は `GameEvent` として溜め、`takeEvents()` で取り出す。状態の正は常にセッション側。
- フェーズは `setup → countdown → playing → finished` の順に進む。

このため、物理とルールは Flame を起動せずにテストできる（`test/game/`、`test/physics/`）。

## Flame との接続: `PendulumFeedingGame`

`lib/game/flame/pendulum_feeding_game.dart` は 1 つの `GameSession` を受け持ち、

1. フレームごとに `FixedStepClock` で必要な回数だけ `session.step()` を呼ぶ。
2. セッションのイベントを演出（得点のハート、新郎の投げる動き）に変える。
3. フェーズとカウントダウンの数字を `ValueNotifier` で Flutter 側へ知らせる。終了直前の得点演出が終わるまでは、終了を少し遅らせて知らせる。

コンポーネント（`lib/game/flame/components/`）は、セッションの状態を描くだけで、ゲームの状態を自分では持たない。入力は `InputLayer` がドラッグを受けてセッションへ渡す。

## Flutter の画面

- 画面はすべて 844×390 の固定座標で組み、`StageViewport` が画面に合わせて拡大縮小する（`lib/ui/widgets/stage.dart`）。Figma の座標をそのまま使え、Flame のワールドとも一致する。
- `GameScreen` は、背景（Flutter）→ 位置決めのヒントとボーナスゲージ → ゲーム（Flame、背景は透明）→ ボタン・カウントダウン・リザルト（Flutter）の順に重ねる。どれを出すかはフェーズで決める。
- リトライでは新しい `GameSession` と `PendulumFeedingGame` を作り直す。
- 遊び方①のデモは、本物の `PendulumFeedingGame` を時間無制限の設定（`howToPlayGameConfig`）で半分の大きさに埋め込んでいる。

## ランキング

`lib/ranking/` は 3 つの層に分かれる。

| クラス | 責務 |
|---|---|
| `RankingService` | 起動時の URL からプレイヤー ID を読み、登録を確かめ、ゲームを記録して順位を返す。遊んだ回数（抽選に使う）も管理する |
| `RankingRepository`（`FirestoreRankingRepository`） | 記録と順位の取得。Firestore のデータ構成とトランザクションを扱う |
| `RankingStorage`（`SharedPreferencesRankingStorage`） | 端末に残す未送信の記録と、最後に確認した遊んだ回数 |

ゲーム側（`GameScreen`）は `RankingService` だけを使う。サービスがなければ全員ゲストとして遊べる。詳細は [firebase.md](firebase.md)。

## テスト

- `test/physics/`: 振り子の物理（TS 版との比較、エネルギー）
- `test/game/`: セッション、ルール、得点、抽選、固定ステップ、時間無制限、得点演出のレイアウト
- `test/ranking/`: ランキングのサービスとリポジトリ（`fake_cloud_firestore` を使用）
- `test/ui/`、`test/widget_test.dart`、`test/game_flow_test.dart`: 画面とゲームの流れ、アセットの対応
- Firestore のセキュリティルールは `tool/firestore_rules/` でエミュレータを使ってテストする（[firebase.md](firebase.md)）
