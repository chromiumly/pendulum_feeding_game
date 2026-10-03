# アセット

画像・アイコン・フォントの置き場所と作り方。

## 置き場所

| パス | 中身 |
|---|---|
| `art/` | 画像の元データ（大きな原寸）。ゲームには同梱しない |
| `assets/images/` | ゲームに同梱する画像。背景以外は `tool/images.dart` が `art/` から作る |
| `assets/icons/` | Figma から書き出したボタンのアイコン（SVG） |
| `assets/fonts/` | M PLUS Rounded 1c（Bold）と Inter（Bold、ExtraBold）。ライセンスは同じフォルダの `OFL-*.txt` |

画像とアイコンのパスは `lib/ui/assets.dart` にまとめている。

## 画像の作り方

`art/` の画像を変えたり足したりしたら、プロジェクトのルートで実行する。

```bash
dart run tool/images.dart
```

- 出力は、ゲームで描く大きさの **4 倍**の解像度（高精細なスマートフォンの画面でもぼやけないように）。
- **食べ物**（`art/food/` → `assets/images/food/`）: 透明な余白を切り取り、見た目がそろうように大きさを決める。縦長・横長の食べ物が極端に大きく・小さく見えないよう、「見えている面積の円の直径」と「長辺」の幾何平均が一定（58 px）になるように縮小する。ゲームは全種類を同じ倍率（1/4）で描く。
- **そのほか**（効果、新婦、新郎、支点）: `tool/images.dart` の `_sprites` に、描く最大の幅と、余白を切り取るかどうかを登録する。新婦・新郎・支点は、コード側で画像全体に対する位置（足元や座面）を使うので、余白を切り取らない。登録のない画像が `art/` にあると、ツールはエラーで止まる。
- **背景**（`assets/images/background/background.png`）は、画面の大きさと大差ないので、ツールでは扱わない。

`test/ui/food_assets_test.dart` が、`art/` と `assets/images/` の画像が過不足なく対応していること（ツールの実行し忘れ）を確かめる。

## 食べ物を変えるとき

食べ物の一覧（ID と点数、好物の順）は `lib/game/model/game_config.dart` の `defaultFoodTypes`。画像のファイル名は ID と同じ（`assets/images/food/<id>.png`）。点数の決め方は [scoring.md](scoring.md)。
