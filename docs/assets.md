# アセット

画像・アイコン・フォントの置き場所と作り方。

## 置き場所

| パス | 中身 |
|---|---|
| `art/` | 画像と音声の元データ（大きな原寸）。ゲームには同梱しない |
| `assets/images/` | ゲームに同梱する画像。背景以外は `tool/images.dart` が `art/` から作る |
| `assets/icons/` | Figma から書き出したボタンのアイコン（SVG） |
| `assets/audio/` | ゲームに同梱する BGM（`bgm/`）と効果音（`sfx/`）。mp3。`tool/audio.dart` が `art/audio/` から作る |
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

## 音声

元データは `art/audio/`、ゲームに同梱するものは `assets/audio/`（flame_audio の標準の置き場所）。`art/audio/` を変えたり足したりしたら、プロジェクトのルートで実行する。

```bash
dart run tool/audio.dart
```

- 何をどうするかは、`tool/audio.dart` の `_recipes` に、`art/audio/` の中のパスごとに登録する（MP3 のビットレート、または「そのままコピー」と、先頭の無音を切るかどうか）。登録のないファイルがあると、ツールはエラーで止まる。
- 作り直すときは、MP3 を 44.1kHz・指定のビットレートにし、**アルバム画像とタグを捨てる**。BGM は、128kbps・ステレオの 3.5MB から、80kbps・ステレオの 1.7MB になった（曲の長さは同じ）。
- **効果音は、音が始まる直前まで先頭を切る。** 元の音源には、音が出るまで約 0.1 秒の無音があり、鳴らしてから聞こえるまでが遅く感じられたため。`_recipes` の `trimBelow` に、「この音量に届いたら始まったと見なす」値を音声ごとに指定する。クリック音が出ないよう、始まりの 5ms は残し、3ms かけて音量を上げる。
  - 食べる音: -60dB（聞こえない大きさ）まで。約 96ms 切った。
  - 投げる音: -26dB まで。この音は、本体（-17dB 前後）の前に、約 50ms の小さなかすれ音（-40dB 前後）があり、投げる操作の直後に鳴らすとそのぶん遅く感じるため、そこまで切った。約 126ms 切った。
  - 元は `art/audio/` にそのまま残るので、切る量はいつでも変えられる。
- **ffmpeg** が必要（`sudo apt install ffmpeg` や `brew install ffmpeg`。パスが通っていなければ、環境変数 `FFMPEG` にパスを入れる）。

| ファイル | 使われ方 |
|---|---|
| `bgm/bgm.mp3` | BGM（ループ用の版）。最後まで再生すると最初から繰り返す |
| `sfx/throw.mp3` | 食べ物を投げたとき |
| `sfx/eat.mp3` | 新婦が食べたとき |

- 音量は `lib/audio/flame_sound_backend.dart` の `bgmVolume`（0.5）と `sfxVolume`（1.0）で変える。
- 効果音を足すときは、`art/audio/sfx/` に置き、`tool/audio.dart` の `_recipes` と `lib/audio/sound_controller.dart` の `Sfx` に追加し、鳴らす場所（`PendulumFeedingGame._handleEvent`）を書く。出典は、下の「出典とクレジット」にも足す。
- mp3 は Safari を含むどのブラウザでも鳴る。

`test/audio/audio_assets_test.dart` が、ゲームが使う音声が揃っていること、`art/audio/` と `assets/audio/` の対応（ツールの実行し忘れ）、BGM が重いまま同梱されていないことを確かめる。

## 食べ物を変えるとき

食べ物の一覧（ID と点数、好物の順）は `lib/game/model/game_config.dart` の `defaultFoodTypes`。画像のファイル名は ID と同じ（`assets/images/food/<id>.png`）。点数の決め方は [scoring.md](scoring.md)。

## 出典とクレジット

ゲームに入っているものの出どころ。

| 種類 | 出どころ |
|---|---|
| 画像（背景、新婦、新郎、振り子の支点、食べ物、ハートや手などの演出） | すべて作者が **Google Flow** で生成した |
| アイコン（SVG） | 作者が Figma でデザインしたもの。音のボタンのアイコンだけは、このリポジトリでコードとして描いた |
| BGM（`bgm/bgm.mp3`、曲名は Paper Petals (Loop Version)） | 作者が **Google Flow Music** で生成した |
| 効果音（`sfx/`） | **OtoLogic**（https://otologic.jp/）から取得した。**クレジットの表記が必要** |
| フォント（M PLUS Rounded 1c、Inter） | SIL Open Font License。ライセンス全文は `assets/fonts/OFL-*.txt` |

### 効果音（OtoLogic）

| 使われ方 | ファイル | 元の効果音名 |
|---|---|---|
| 食べたとき | `eat.mp3` | Anime_Motion15-1(High) |
| 投げたとき | `throw.mp3` | Motion-Agility01-2(Low) |

- 表記は、**OtoLogic**（https://otologic.jp/）の利用規約が指定する形に合わせる。README の Credits と、ゲーム内の遊び方の 3 ページ目「クレジット」に書いてある（文面は `lib/app/how_to_play_credits.dart` の `creditGroups`）。
- `tool/audio.dart` で作り直すと、ファイルのタグ（作者名や効果音名）は捨てられる。元の音源は `art/audio/sfx/` にそのまま残している。
- 効果音を足したり差し替えたりしたら、この表も更新する。
- 第三者の素材（効果音とフォント）は、リポジトリの [LICENSE](../LICENSE) の対象外で、それぞれの規約に従う。
