# Firebase（ランキング）

スコアの記録とランキングは Cloud Firestore（プロジェクト `pendulum-feeding-game`）に置く。アプリは Firebase Authentication を使わず、読み書きできる範囲はすべてセキュリティルール（`firestore.rules`）で決めている。

## プレイヤー ID

- ゲストに配る QR コードの URL に、16 文字の英小文字・数字の ID が入っている: `https://chromiumly.github.io/pendulum_feeding_game/?id=xxxxxxxxxxxxxxxx`
- ID は秘密の値。知っていれば誰でもその人として記録できる。誰がどの ID かは、主催者がプロジェクトの外で管理する。
- アプリは **URL の `id` だけ**を見る。端末には覚えさせないので、`id` のない URL で開くと、その端末でもゲスト（記録なし）になる。再読み込みやブックマークでは URL の `id` は消えない。
- 登録されていない ID、形式の違う ID もゲストとして遊べる。

## データ構成

| コレクション | 中身 | クライアントの権限 |
|---|---|---|
| `players/{playerId}` | 登録済みの ID。`gamesPlayed`（記録したゲーム数）と `lastPlayId`（最後に数えたプレイ） | 自分の ID の取得のみ。一覧不可。作成・削除は管理ツールだけ。`gamesPlayed` は新しいプレイと同時に +1 だけ更新できる |
| `plays/{playId}` | 全プレイ（`playerId`、`score`、`createdAt`） | 作成のみ。読めない（主催者は Firebase コンソールで見る） |
| `scores/{playId}` | 各プレイの得点だけ（誰のものかは含まない） | 読める。「全試行中 N 位」に使う |
| `bests/{bestKey}` | 各プレイヤーの自己ベスト。キーは ID の SHA-256（16 進小文字）で、ID は分からない | 読める。「挑戦者中 N 位」に使う。上がるときだけ更新できる |

1 回の記録は 1 つのトランザクションで、`plays`・`scores`・`players` の `gamesPlayed` +1、自己ベストを更新するときは `bests` も書く。ルールは、これらが常に一緒に、登録済みの ID の新しいプレイとしてのみ書かれることを保証する。得点は 0〜10000 の整数でなければならない（ゲームで取れる最高点は約 8700 なので、そのすぐ上に上限を置いて、作り話の得点を弾く。得点の仕組みを変えて最高点が上がるときは、`firestore.rules` の `validScore` を見直す）。

順位は、自分より高い得点の数を数えて +1 する（同点は同じ順位）。数え上げは Firestore の集計クエリ（count）で行う。

## アプリの動き

- 起動時に URL の ID を読み、`players/{id}` を取得して登録を確かめる。このとき `gamesPlayed` も受け取る。
- ゲームが終わると記録を送る。送る前に端末（Web では localStorage）にも保存し、成功したら消す。失敗したら端末に残し、次の起動時や次の記録時に送り直す。同じ記録を送り直しても、`playId` で見分けて二重には記録しない。
- ルールに拒否された記録は、送り直しても通らないので端末から消す。
- プレイ回数ボーナスに使う遊んだ回数は「サーバーで確認済みの回数 + 端末に残っている未送信の記録の数」。オフラインでも最後に確認した回数を使う。

端末に保存するキーは `ranking.` で始まる（`ranking.pending`、`ranking.recordedGames.<ID>`）。PC のブラウザでは、開発者ツールのコンソールで次を実行すると、このゲームのデータだけを消せる（同じ `github.io` のほかのサイトのデータは消えない）。

```js
Object.keys(localStorage).filter(k => k.startsWith('ranking.')).forEach(k => localStorage.removeItem(k))
```

## 管理ツール

`tool/ranking/player_ids.dart`（プロジェクトのルートで実行）:

```bash
dart run tool/ranking/player_ids.dart generate [--count 50]   # ID を作り、players.csv と QR コードの印刷用ページを書き出す
dart run tool/ranking/player_ids.dart register [--emulator]   # players.csv の ID を Firestore に登録する（登録済みの回数は消えない）
dart run tool/ranking/player_ids.dart reset [--emulator]      # 各コレクションの件数を表示する（何も消さない）
dart run tool/ranking/player_ids.dart reset --confirm pendulum-feeding-game   # 全データを消して ID を登録し直す
```

- 出力先の `tool/ranking/out/` と、サービスアカウントの鍵を置く `.firebase/` は git の管理外。どちらも秘密の情報なので、共有しないこと。
- `generate` は、既に `players.csv` があると上書きしない（配った ID を失わないため）。
- `reset` はリハーサルの後などに使う。ID は変わらないので、配った QR コードはそのまま使える。

## セキュリティルールのテストと反映

ルールのテストは Firestore エミュレータで動かす。Node.js と Java が必要。

```bash
cd tool/firestore_rules
npm install
npm test
```

本番への反映（Firebase CLI にログインした状態で）:

```bash
cd tool/firestore_rules
npx firebase deploy --only firestore:rules --config ../../firebase.json --project pendulum-feeding-game
```

ルールとアプリの両方を変えるときは、**ルールを先に反映してから**アプリを公開する（[deployment.md](deployment.md)）。
