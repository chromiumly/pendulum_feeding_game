/// What the talk says, as in the Figma design.
library;

/// The cover.
abstract final class TalkCover {
  static const kicker = 'Lightning Talk';
  static const title = '結婚式のためにゲームを作った話';

  // The page is public: take the presenter's name off after the wedding.
  static const date = '2026.10.31';
  static const presenter = '黒川 純平';
}

/// The award page.
abstract final class TalkAward {
  /// The game's title, above 表彰式.
  static const gameTitle = '花嫁もぐもぐチャレンジ！';
}

/// The concept slide.
abstract final class TalkConcept {
  static const title = 'コンセプト';
  static const message = '待ち時間にスマホで気軽に遊べるゲーム';
  static const points = [
    'インストール不要なWebアプリ',
    '1回あたりは短時間で済む',
    '簡単に操作できる',
    'ランキングで競える',
  ];
}

/// The theme slide: two points, the second with two points under it.
abstract final class TalkTheme {
  static const title = 'テーマ';
  static const message = '食べ物と二重振り子のコラボ';
  static const points = ['新婦は食べるのが大好き', '二重振り子は夫婦生活と似ている'];
  static const subPoints = [
    'お互いの動きが影響しあいながら\n一体となって動く',
    '遠い先は予測できないため\nふたりで少しずつ進んでいく',
  ];
}

/// The slide on how the game was made.
abstract final class TalkMaking {
  static const title = '作り方';
  static const message = '思いつきからみなさんのスマホに届くまで';
  static const making = '作る（これまで）';
  static const playing = '遊ぶ（本日）';
}
