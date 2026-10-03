# デプロイ

ゲームは Flutter Web としてビルドし、GitHub Pages で公開する。

- 公開 URL: https://chromiumly.github.io/pendulum_feeding_game/
- ワークフロー: `.github/workflows/deploy.yml`

## 公開の流れ

`main` ブランチへのプッシュ（または Actions 画面からの手動実行）で、GitHub Actions が次を行う。

1. Flutter 3.47.5（stable）を用意し、`flutter pub get`
2. `flutter build web --release --base-href /pendulum_feeding_game/`
3. `build/web` を GitHub Pages に公開

ワークフローはテストや静的解析を実行しない。プッシュする前に手元で確認する。

```bash
flutter analyze
flutter test
```

## Firestore のルールとの順番

アプリの公開とは別に、Firestore のセキュリティルールは手動で反映する（[firebase.md](firebase.md#セキュリティルールのテストと反映)）。新しいアプリが新しいルールを前提にしているときは、**ルールを先に反映してから**アプリをプッシュする。逆の順番だと、その間の記録は拒否され、端末からも消える。

## キャッシュ

GitHub Pages はすべてのファイルを 10 分間キャッシュしてよいとして配信し（`cache-control: max-age=600`）、Flutter のファイル名はバージョンが変わっても同じ。そのため公開直後の 10 分ほどは、ブラウザが古い版を表示することがある。確かめるときは、10 分ほど待ってからタブを開き直す。

本番（披露宴の当日）の前は、最後の公開を前日までに済ませておくと安全。

## 本番前の準備

1. `tool/ranking/player_ids.dart generate` で ID と QR コードを作り、`register` で登録する（[firebase.md](firebase.md#管理ツール)）。
2. リハーサルの記録は `reset --confirm pendulum-feeding-game` で消す。テストに使った端末に未送信の記録が残っていると、後で送られるので、その端末のこのゲームのデータも消しておく。
