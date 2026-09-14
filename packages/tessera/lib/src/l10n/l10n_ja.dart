import '../cube/layout_aggregate.dart';
import '../expr/expr_type.dart';
import '../expr/expression_error.dart';
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
  String stdDevOf(String t) => '$tの標準偏差';

  @override
  String stdDevPopulationOf(String t) => '$tの母標準偏差';

  @override
  String varianceOf(String t) => '$tの分散';

  @override
  String variancePopulationOf(String t) => '$tの母分散';

  @override
  String countOf(String t) => '$tの件数';

  @override
  String distinctCountOf(String t) => '$tの一意の値の数';

  @override
  String get countLabel => '件数';

  @override
  String percentOfTotal(String base, TotalOf of) => switch (of) {
    TotalOf.row => '$base（行合計に対する%）',
    TotalOf.column => '$base（列合計に対する%）',
    TotalOf.grand => '$base（総計に対する%）',
    TotalOf.parentRow => '$base（親行に対する%）',
    TotalOf.parentColumn => '$base（親列に対する%）',
  };

  @override
  String differenceFrom(String base, String item, {required bool percent}) =>
      percent ? '$base（$itemとの差の%）' : '$base（$itemとの差）';

  @override
  String get previousItem => '前';

  @override
  String get nextItem => '次';

  @override
  String runningTotalOf(String base) => '$base（累計）';

  @override
  String rankOf(String base) => '$base（順位）';

  @override
  String get showValuesAs => '値の表示形式';

  @override
  String valueDisplayName(ValueDisplay display) => switch (display) {
    ValueDisplay.plain => 'そのままの値',
    ValueDisplay.percentOfRow => '行合計に対する%',
    ValueDisplay.percentOfColumn => '列合計に対する%',
    ValueDisplay.percentOfGrand => '総計に対する%',
    ValueDisplay.percentOfParentRow => '親行に対する%',
    ValueDisplay.percentOfParentColumn => '親列に対する%',
    ValueDisplay.differenceFromPreviousRow => '前の行との差',
    ValueDisplay.differenceFromPreviousColumn => '前の列との差',
    ValueDisplay.percentDifferenceFromPreviousRow => '前の行との差の%',
    ValueDisplay.percentDifferenceFromPreviousColumn => '前の列との差の%',
    ValueDisplay.runningTotalRows => '行方向の累計',
    ValueDisplay.runningTotalColumns => '列方向の累計',
    ValueDisplay.rankRows => '行内の順位',
    ValueDisplay.rankColumns => '列内の順位',
  };

  @override
  String get formula => '数式';

  @override
  String get labelField => 'ラベル';

  @override
  String get countOfFacts => 'レコード数';

  @override
  String get sum => '合計';

  @override
  String get average => '平均';

  @override
  String get minimum => '最小値';

  @override
  String get maximum => '最大値';

  @override
  String get standardDeviation => '標準偏差';

  @override
  String get populationStandardDeviation => '母標準偏差';

  @override
  String get variance => '分散';

  @override
  String get populationVariance => '母分散';

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

  @override
  String get filter => 'フィルター';

  @override
  String get noFilter => 'フィルターなし';

  @override
  String get addCondition => '条件を追加';

  @override
  String get addGroup => 'グループを追加';

  @override
  String get addExpression => '式を追加';

  @override
  String get matchAll => 'すべての条件を満たす';

  @override
  String get matchAny => 'いずれかの条件を満たす';

  @override
  String get negate => '否定';

  @override
  String get opEquals => 'に等しい';

  @override
  String get opNotEquals => 'に等しくない';

  @override
  String get opLess => 'より小さい';

  @override
  String get opLessOrEqual => '以下';

  @override
  String get opGreater => 'より大きい';

  @override
  String get opGreaterOrEqual => '以上';

  @override
  String get opBetween => 'の範囲内';

  @override
  String get opContains => 'を含む';

  @override
  String get opStartsWith => 'で始まる';

  @override
  String get opEndsWith => 'で終わる';

  @override
  String get opIsEmpty => 'が空';

  @override
  String get opIsNotEmpty => 'が空でない';

  @override
  String get opIsOneOf => 'のいずれか';

  @override
  String get opIsTrue => 'が真';

  @override
  String get opIsFalse => 'が偽';

  @override
  String get customFilter => 'カスタムフィルター';

  @override
  String get expression => '式';

  @override
  String get selectValues => '値を選択…';

  @override
  String selectedCount(int count) => '$count 件選択';

  @override
  String get clear => 'クリア';

  @override
  String get apply => '適用';

  @override
  String get column => '列';

  @override
  String get value => '値';

  @override
  String exprTypeName(ExprType type) => switch (type) {
    ExprType.number => '数値',
    ExprType.text => 'テキスト',
    ExprType.boolean => '真偽値',
    ExprType.date => '日付',
  };

  @override
  String expressionErrorText(ExpressionErrorKind kind, List<String> a) =>
      switch (kind) {
        ExpressionErrorKind.unexpectedCharacter => '予期しない文字「${a[0]}」',
        ExpressionErrorKind.unterminatedText => 'テキストが閉じられていません',
        ExpressionErrorKind.unterminatedName => '列名の後に「]」がありません',
        ExpressionErrorKind.unterminatedDate => '日付の後に「#」がありません',
        ExpressionErrorKind.invalidNumber => '無効な数値「${a[0]}」',
        ExpressionErrorKind.invalidDate => '無効な日付「${a[0]}」',
        ExpressionErrorKind.unexpectedToken => '予期しない「${a[0]}」',
        ExpressionErrorKind.unexpectedEnd => '式が途中で終わっています',
        ExpressionErrorKind.unknownColumn => '不明な列「${a[0]}」',
        ExpressionErrorKind.unknownFunction => '不明な関数「${a[0]}」',
        ExpressionErrorKind.argumentCount =>
          '${a[0]} の引数は ${a[1]} 個ですが、${a[2]} 個指定されました',
        ExpressionErrorKind.argumentType =>
          '${a[0]} の引数 ${a[1]} は ${a[3]} ではなく ${a[2]} である必要があります',
        ExpressionErrorKind.operandType =>
          '${a[0]} のオペランドは ${a[2]} ではなく ${a[1]} である必要があります',
        ExpressionErrorKind.incompatibleTypes =>
          '${a[0]} は ${a[1]} と ${a[2]} に適用できません',
        ExpressionErrorKind.unknownType => '型を決定できません',
        ExpressionErrorKind.notAllowedHere => '「${a[0]}」はここでは使用できません',
        ExpressionErrorKind.resultType => '式は ${a[1]} ではなく ${a[0]} である必要があります',
      };
}
