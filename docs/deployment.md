# デプロイ

ゲームは Flutter Web としてビルドし、GitHub Pages で公開する。

- 公開 URL: https://chromiumly.github.io/pendulum_feeding_game/
- ワークフロー: `.github/workflows/deploy.yml`

## 公開の流れ

`main` ブランチへのプッシュ（または Actions 画面からの手動実行）で、GitHub Actions が次を行う。

1. Flutter 3.47.5（stable）を用意し、`flutter pub get`
2. `flutter analyze` と `flutter test`。**どちらかが失敗すると、そこで止まり、公開されない**
3. `flutter build web --release --base-href /pendulum_feeding_game/`
4. `build/web` を GitHub Pages に公開

Firestore のセキュリティルールのテスト（エミュレータが必要）は、ここには入っていない。ルールを変えたときは、手元で実行する（[firebase.md](firebase.md#セキュリティルールのテストと反映)）。プッシュする前に、手元でも同じ確認をしておくと、失敗に気づくのが早い。

```bash
flutter analyze
flutter test
```

## Firestore のルールとの順番

アプリの公開とは別に、Firestore のセキュリティルールは手動で反映する（[firebase.md](firebase.md#セキュリティルールのテストと反映)）。新しいアプリが新しいルールを前提にしているときは、**ルールを先に反映してから**アプリをプッシュする。逆の順番だと、その間の記録は拒否され、端末からも消える。

## 読み込み中の表示

ゲームは、最初に数十 MB（`canvaskit.wasm` が約 7MB、`main.dart.js` が約 2MB、フォントと画像が数 MB）を読み込むので、通信が細いと時間がかかる。その間、真っ白な画面にならないよう、**読み込み中の画面**を出している。

- 見た目は `web/index.html`（ゲームのクリーム色、茶色の枠、ゲージと同じオレンジのバーと、流れる光）、動きは `web/flutter_bootstrap.js`。
- バーは、**起動の段階を目印に進む**。Flutter は、読み込んだバイト数を教えてくれないため。各段階（ページのファイル → ゲームのコードが届く → エンジンが起動 → ゲームが動く）に入ると、バーがその段階の始まりまで進み、段階の間は少しずつ進むが、最後まで行かない。**ゲームの最初のフレームが描かれると、バーが満ちて、画面が消える。** なので、百分率ではなく、目安。
- 30 秒たっても終わらないときは、「読み込みに時間がかかっています」と出す。
- `flutter_bootstrap.js` の `{{...}}` の部分は、`flutter build` が埋める。消すとビルドが壊れる。

## キャッシュ

GitHub Pages はすべてのファイルを 10 分間キャッシュしてよいとして配信し（`cache-control: max-age=600`）、Flutter のファイル名はバージョンが変わっても同じ。そのため公開直後の 10 分ほどは、ブラウザが古い版を表示することがある。確かめるときは、10 分ほど待ってからタブを開き直す。

本番（披露宴の当日）の前は、最後の公開を前日までに済ませておくと安全。

## 本番前の準備

1. `tool/ranking/player_ids.dart generate` で ID と QR コードを作り、`register` で登録する（[firebase.md](firebase.md#管理ツール)）。
2. リハーサルの記録は `reset --confirm pendulum-feeding-game` で消す。テストに使った端末に未送信の記録が残っていると、後で送られるので、その端末のこのゲームのデータも消しておく。
