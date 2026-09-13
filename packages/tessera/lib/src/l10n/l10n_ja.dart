import '../facts/dimension.dart';
import 'tessera_strings.dart';

/// ja texts. Native review welcome.
final class TesseraStringsJa extends TesseraStrings {
  const TesseraStringsJa();

  @override
  String get languageCode => 'ja';

  @override
  String sumOf(String t) => '$tの合計';

  @override
  String averageOf(String t) => '$tの平均';

  @override
  String minimumOf(String t) => '$tの最小値';

  @override
  String maximumOf(String t) => '$tの最大値';

  @override
  String countOf(String t) => '$tの件数';

  @override
  String distinctCountOf(String t) => '$tの一意の値の数';

  @override
  String get countLabel => '件数';

  @override
  String get countOfFacts => '行数';

  @override
  String get sum => '合計';

  @override
  String get average => '平均';

  @override
  String get minimum => '最小値';

  @override
  String get maximum => '最大値';

  @override
  String get countOfValues => '値の件数';

  @override
  String get distinctCount => '一意の値の数';

  @override
  String datePartName(DatePart part) => switch (part) {
    DatePart.year => '年',
    DatePart.quarter => '四半期',
    DatePart.month => '月',
    DatePart.week => '週',
    DatePart.day => '日',
    DatePart.weekday => '曜日',
    DatePart.hour => '時',
  };

  @override
  String datePartLabel(String column, DatePart part) {
    final p = datePartName(part);
    return '$column（$p）';
  }

  static const _months = [
    '1月',
    '2月',
    '3月',
    '4月',
    '5月',
    '6月',
    '7月',
    '8月',
    '9月',
    '10月',
    '11月',
    '12月',
  ];

  static const _weekdays = ['月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日', '日曜日'];

  @override
  String monthName(int month) => _months[month - 1];

  @override
  String weekdayName(int weekday) => _weekdays[weekday - 1];

  @override
  String quarter(int q) => 'Q$q';

  @override
  String get decimalSeparator => '.';

  @override
  String get groupSeparator => ',';

  @override
  String get rows => '行';

  @override
  String get columns => '列';

  @override
  String get values => '値';

  @override
  String get emptyGroup => '(空)';

  @override
  String get total => '合計';

  @override
  String get dropDimensionsHere => 'ここにディメンションをドロップ';

  @override
  String get addDimension => 'ディメンションを追加';

  @override
  String get addAggregate => '集計を追加';

  @override
  String get search => '検索';

  @override
  String get alreadyInUse => '使用中';

  @override
  String get function => '関数';

  @override
  String get expand => '展開';

  @override
  String get largeExpansionTitle => '大規模な展開';

  @override
  String get sortAscending => '昇順で並べ替え';

  @override
  String get sortDescending => '降順で並べ替え';

  @override
  String get inheritSort => '上の階層と同じ順序';

  @override
  String get totalsAtEnd => '合計を末尾に';

  @override
  String get totalsAtStart => '合計を先頭に';

  @override
  String get totalsHidden => '合計を非表示';

  @override
  String get subtotalsAbove => '小計をグループの上に';

  @override
  String get subtotalsBelow => '小計をグループの下に';

  @override
  String get subtotalsLeft => '小計をグループの左に';

  @override
  String get subtotalsRight => '小計をグループの右に';

  @override
  String get subtotalsHidden => '小計を非表示';

  @override
  String get expandAll => 'すべて展開';

  @override
  String get collapseAll => 'すべて折りたたむ';

  @override
  String largeExpansion(String label, int added, {required bool isRow}) =>
      '「$label」を展開すると $added ${isRow ? '行' : '列'}が追加されます。続行しますか？';
}
