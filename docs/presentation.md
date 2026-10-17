# 発表ページ（ライトニングトークと表彰式）

披露宴でのライトニングトークと、ランキングの表彰に使うページ。ゲームと同じプロジェクトにあり、エントリポイントだけが別になっている（`lib/presentation/main.dart`）。

- 公開 URL: https://chromiumly.github.io/pendulum_feeding_game/present/
- ゲームとは別にビルドするので、ゲームの読み込みサイズや動きは変わらない（[deployment.md](deployment.md)）。
- **挑戦者の名前はページに含まれない。** 名前は当日、名簿ファイルとして読み込む（[名簿](#名簿)）。URL を知られても、見えるのはスライドと、名前のないランキングだけ。
- ただし**表紙には発表者の実名と日付がある**（`talk_content.dart` の `TalkCover`）。公開ページなので、結婚式が終わったら名前を消す。

## ページ

| ページ | 中身 |
|---|---|
| 1. 表紙 | 左上に「Lightning Talk」、タイトルと下線、日付と発表者名。後ろをゲームの食べ物（全 20 種）が、薄く、回りながら左から右へ流れる |
| 2. コンセプト | 「待ち時間にスマホで気軽に遊べるゲーム」と 4 つの点。右にスマホで遊ぶゲスト 2 人 |
| 3. テーマ | 「食べ物と二重振り子のコラボ」と点。右の正方形のカード（うっすら青緑）で、ゲームの二重振り子が動く |
| 4. 作り方 | 素材 → Figma → Claude Code → Flutter → GitHub Pages → みなさんのスマホ → Firebase の図 |
| 5. 表彰式 | ゲームのタイトル（花嫁もぐもぐチャレンジ！）と「表彰式」 |
| 6. ランキング | 上位 3 位までの表。同じ順位の人は、縦に並べて、入らなければ列を足す |

- デザインは Figma（「結婚式」ファイルの「プレゼンテーション」ページ）で作り、座標と色はそれに合わせている。文言は `lib/presentation/talk_content.dart` にまとめてある。
- 表紙以外の右下に「2 / 6」のようなページ番号が出る（表紙も数に入る）。
- 背景はゲームの背景をぼかして、クリーム色を重ねたもの。表彰式とランキングには、金色とゆっくり瞬く光を足している。
- 文字には、大きさに応じて 2〜4px の白い縁取りがある（`SlideText`）。
- 金色の文字（表彰式、ランキング、1位）には、光の帯が 1 本、3.6 秒ごとに斜めに流れる。表彰式の上下の線も、同じ間隔で光が流れる。
- タイトルの下線は表彰式の線と同じ金色で、右へ行くほど透ける（表紙は両端が透ける）。ゲームの回数ボーナスのゲージと同じ間隔で、光が左から右へ流れる。
- テーマの振り子は、ゲームと同じパラメータ・刻み幅・RK4 で、ゲームの開始（初期の姿勢に、スタートで与える速さ）から動く。見た目もゲームと同じ（ロープ・支点・新婦の絵）。新婦の座面の軌跡を約 5 秒分、半透明で後ろに残す。ほかのページから戻ると最初から動く。
- 画像は `assets/presentation/` にある（ゲストの絵、スマホ、ツールのアイコン）。Web のアセットは使うときに読み込まれるので、ゲームはダウンロードしない。

## 操作

| 操作 | キー |
|---|---|
| 次のページ | → ↓ PageDown Space Enter（プレゼン用のクリッカーは PageDown を送る） |
| 前のページ | ← ↑ PageUp Backspace |
| 最初・最後のページ | Home・End |
| ランキングの固定・再開 | F、またはランキングの右下のボタンをクリック |

最初のクリックかキーで、全画面に切り替わる。全画面をやめるときは Esc。

## ランキング

- 表の列は「順位・スコア・名前」。1 位の行だけ大きい。
- 順位の数え方はゲームと同じで、自分より高い自己ベストの数 + 1。**同じ自己ベストの人は、同じ行に全員並ぶ。** その分、次の順位は空く（例: 2 位が 2 人なら 3 位はいない）。空いた行と、挑戦者が足りない行は「—」。
- Firestore の `bests`（自己ベスト）と `scores`（全プレイ）を、リアルタイムで読む。どちらも元から誰でも読めるもので、**Firestore のルールとゲームには手を入れていない**（[firebase.md](firebase.md#データ構成)）。
- **ランキングのページに入った瞬間の順位で固定する。** 固定したら、ほかのページに移って戻っても固定のまま（発表中に順位が入れ替わらないように）。F かボタンで、リアルタイムに戻す・また固定する。右下に「LIVE」か「hh:mm の結果で固定中」と出る。
- 通信が切れても、最後に取れた結果が残る（「通信が切れています」と出る）。
- 名簿にない人は「？？？」と出る。

1 人ごとのプレイ回数（最多プレイ賞など）は出せない。プレイ回数は `players/{ID}` にあり、ID なしでは読めないため。

## 名簿

ランキングの名前は、**名簿ファイル**（`roster.json`）から出す。中身は「プレイヤー ID の SHA-256 → 表示名」だけで、**ID そのものは入っていない**。`bests` のキーと同じハッシュなので、これで突き合わせられる。ハッシュから ID は分からないので、名簿が漏れても、その人として記録することはできない。

名簿は、リポジトリにも、公開されるページにも、Firestore にも入れない。

### 作り方

1. `tool/ranking/out/players.csv`（git の管理外）の各行の末尾に、4 列目として表示名を足す（例: `1,xxxxxxxxxxxxxxxx,https://…,山田 花子`）。投影されるので、出してよい表記にする。
2. 書き出す:

```bash
dart run tool/ranking/player_ids.dart roster            # players.csv の 4 列目の名前で
dart run tool/ranking/player_ids.dart roster --dummy    # 全員ダミーの名前で（リハーサル用）
```

`tool/ranking/out/roster.json` ができる。名前のない行があると、どの番号かを示して止まる。

### 読み込み

- 発表ページに `roster.json` をドラッグ＆ドロップする。名簿がないときは左下に「名簿が読み込まれていません」と出ていて、その「ファイルを選ぶ」からも読み込める。
- 読み込んだ名簿は、そのブラウザの localStorage（キー `presentation.roster`）に残る。再読み込みしても、URL を開き直しても名前が出る（同じ PC の同じブラウザに限る）。期限はない。
- 読み込みに使ったファイルは、その場で PC から消しておく。

### 消し方

終わったら手で消す。発表ページを開いた状態で、開発者ツール（F12）のコンソールで次を実行する。

```js
Object.keys(localStorage).filter(k => k.startsWith('presentation.')).forEach(k => localStorage.removeItem(k))
```

開発者ツールの Application タブ → Local Storage → `https://chromiumly.github.io` から、`presentation.roster` を選んで消してもよい。

「サイトのデータを削除」でも消えるが、`chromiumly.github.io` のほかのページのデータも一緒に消える（ゲームの未送信の記録など）。

## フォント

ゲームのフォントは、ゲームが書く文字だけに削ってある（[assets.md](assets.md)）。名簿の名前にはどんな字が来るか分からないので、発表ページは**削っていない元のフォント**（`art/fonts/MPLUSRounded1c-Bold.ttf`、約 3.5MB）を起動時に読み込む。

- このフォントはアセットとして置いているだけで、アプリのフォント（`pubspec.yaml` の `fonts:`）ではない。なので、ゲームはダウンロードしない。
- `lib/presentation/` の文字は、ゲーム用に削ったフォントには入れない（`tool/fonts.dart` と `test/ui/fonts_test.dart` はこのフォルダを読まない）。その代わり、元のフォントにすべてあることをテストしている。

## 手元で試す

```bash
flutter run -d web-server --web-port 5002 -t lib/presentation/main.dart                                      # 本番の Firestore を読む
flutter run -d web-server --web-port 5001 -t lib/presentation/main.dart --dart-define=PRESENTATION_DEMO=true  # ダミーのデータで
```

VS Code では「実行とデバッグ」から「Presentation」か「Presentation (demo data)」を選ぶ（`.vscode/launch.json`）。

- 本番の Firestore は読むだけなので、データは壊れない。
- ダミーのデータでは、12 人のダミーの挑戦者（3 位が同点）が出て、4 秒ごとに誰かの自己ベストが上がる。名簿も入っているので、ファイルなしで名前が出る。

## 当日の流れ

1. 前日か当日の朝、借りた PC で公開 URL を開き、`roster.json` を読み込む。ファイルは消す。
2. プロジェクター、会場の通信、クリッカーで送れるかを確かめる。
3. 全画面にして、式場の人に渡す。式場の人はクリッカーで送るだけ。
4. 何かあったら、URL を開き直せば名簿ごと戻る。
5. 終わったら、名簿を消す（[消し方](#消し方)）。

## コード

| ファイル | 中身 |
|---|---|
| `lib/presentation/main.dart` | エントリポイント。フォントと名簿を読み、Firestore（かダミー）を選ぶ |
| `presentation_screen.dart` | ページ送り、キー操作、全画面、名簿の読み込み |
| `slides/talk_slides.dart` | 表紙、コンセプト、テーマ、表彰式 |
| `slides/making_slide.dart` | 作り方の図 |
| `slides/ranking_slide.dart` | ランキング |
| `slides/slide_parts.dart` | 共通の部品（光が流れる下線、見出し、点、ページ番号、カード、点線の枠） |
| `slides/pendulum_demo.dart` | テーマのページで動く振り子（ロープはゲームと同じ `lib/ui/rope_painter.dart` で描く） |
| `talk_content.dart` | スライドの文言 |
| `presentation_assets.dart` | 画像のパス（`assets/presentation/`） |
| `slide_frame.dart`, `slide_style.dart` | 1920x1080 の画面、背景、金色の文字、光、色と文字の大きさ |
| `standings.dart` | 順位の計算（同じ自己ベストは同じ行） |
| `ranking_board.dart` | リアルタイムと固定の切り替え |
| `standings_source.dart` | Firestore の `bests` と `scores` の購読、ダミーのデータ |
| `roster.dart`, `roster_store.dart` | 名簿ファイルの読み書き、localStorage への保存 |
| `browser/` | 全画面とファイルの読み込み（Web のときだけ。テストでは何もしない） |
