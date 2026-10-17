/// Made-up Japanese names, for rehearsing the ranking before the real
/// roster is filled in.
library;

const _familyNames = [
  '佐藤',
  '鈴木',
  '高橋',
  '田中',
  '伊藤',
  '渡辺',
  '山本',
  '中村',
  '小林',
  '加藤',
  '吉田',
  '山田',
  '佐々木',
  '山口',
  '松本',
  '井上',
  '木村',
  '林',
  '斎藤',
  '清水',
];

const _givenNames = [
  '花子',
  '健',
  '美咲',
  '翔太',
  '陽菜',
  '大輝',
  '結衣',
  '拓海',
  'さくら',
  '悠斗',
  '葵',
  '蓮',
  '彩',
  '湊',
  '真由',
  '颯太',
  '七海',
  '亮',
  '千尋',
  '直樹',
  '愛',
  '大和',
  '舞',
  '海斗',
  '優花',
  '樹',
  '莉子',
  '陸',
  '杏',
  '誠',
];

/// Returns the [index]th made-up name (from 0), e.g. 佐藤 花子. The first 60
/// are all different.
String dummyName(int index) {
  final family = _familyNames[index % _familyNames.length];
  final given = _givenNames[(index * 7) % _givenNames.length];
  return '$family $given';
}
