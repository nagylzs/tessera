import '../cube/layout_aggregate.dart';
import '../expr/expr_type.dart';
import '../expr/expression_error.dart';
import '../facts/dimension.dart';
import 'tessera_strings.dart';

/// zh texts. Native review welcome.
final class TesseraStringsZh extends TesseraStrings {
  const TesseraStringsZh();

  @override
  String get languageCode => 'zh';

  @override
  String sumOf(String t) => '$t的总和';

  @override
  String averageOf(String t) => '$t的平均值';

  @override
  String minimumOf(String t) => '$t的最小值';

  @override
  String maximumOf(String t) => '$t的最大值';

  @override
  String stdDevOf(String t) => '$t的标准差';

  @override
  String stdDevPopulationOf(String t) => '$t的总体标准差';

  @override
  String varianceOf(String t) => '$t的方差';

  @override
  String variancePopulationOf(String t) => '$t的总体方差';

  @override
  String countOf(String t) => '$t的计数';

  @override
  String distinctCountOf(String t) => '$t的唯一值数';

  @override
  String get countLabel => '计数';

  @override
  String percentOfTotal(String base, TotalOf of) => switch (of) {
    TotalOf.row => '$base 占行汇总的%',
    TotalOf.column => '$base 占列汇总的%',
    TotalOf.grand => '$base 占总计的%',
    TotalOf.parentRow => '$base 占父行的%',
    TotalOf.parentColumn => '$base 占父列的%',
  };

  @override
  String differenceFrom(String base, String item, {required bool percent}) =>
      percent ? '$base 与$item的差异百分比' : '$base 与$item的差异';

  @override
  String get previousItem => '上一项';

  @override
  String get nextItem => '下一项';

  @override
  String runningTotalOf(String base) => '$base 累计';

  @override
  String rankOf(String base) => '$base 排名';

  @override
  String get showValuesAs => '值显示方式';

  @override
  String valueDisplayName(ValueDisplay display) => switch (display) {
    ValueDisplay.plain => '原始值',
    ValueDisplay.percentOfRow => '占行汇总的%',
    ValueDisplay.percentOfColumn => '占列汇总的%',
    ValueDisplay.percentOfGrand => '占总计的%',
    ValueDisplay.percentOfParentRow => '占父行的%',
    ValueDisplay.percentOfParentColumn => '占父列的%',
    ValueDisplay.differenceFromPreviousRow => '与上一行的差异',
    ValueDisplay.differenceFromPreviousColumn => '与上一列的差异',
    ValueDisplay.percentDifferenceFromPreviousRow => '与上一行的差异百分比',
    ValueDisplay.percentDifferenceFromPreviousColumn => '与上一列的差异百分比',
    ValueDisplay.runningTotalRows => '按行累计',
    ValueDisplay.runningTotalColumns => '按列累计',
    ValueDisplay.rankRows => '行内排名',
    ValueDisplay.rankColumns => '列内排名',
  };

  @override
  String get formula => '公式';

  @override
  String get labelField => '标签';

  @override
  String get countOfFacts => '行数';

  @override
  String get sum => '求和';

  @override
  String get average => '平均值';

  @override
  String get minimum => '最小值';

  @override
  String get maximum => '最大值';

  @override
  String get standardDeviation => '标准差';

  @override
  String get populationStandardDeviation => '总体标准差';

  @override
  String get variance => '方差';

  @override
  String get populationVariance => '总体方差';

  @override
  String get countOfValues => '值计数';

  @override
  String get distinctCount => '唯一值计数';

  @override
  String datePartName(DatePart part) => switch (part) {
    DatePart.year => '年',
    DatePart.quarter => '季度',
    DatePart.month => '月',
    DatePart.week => '周',
    DatePart.day => '日',
    DatePart.weekday => '星期',
    DatePart.hour => '小时',
  };

  @override
  String datePartLabel(String column, DatePart part) {
    final p = datePartName(part);
    return '$column（$p）';
  }

  static const _months = [
    '一月',
    '二月',
    '三月',
    '四月',
    '五月',
    '六月',
    '七月',
    '八月',
    '九月',
    '十月',
    '十一月',
    '十二月',
  ];

  static const _weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];

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
  String get values => '值';

  @override
  String get emptyGroup => '(空)';

  @override
  String get total => '合计';

  @override
  String get dropDimensionsHere => '将维度拖到此处';

  @override
  String get addDimension => '添加维度';

  @override
  String get addAggregate => '添加聚合';

  @override
  String get search => '搜索';

  @override
  String get alreadyInUse => '已在使用';

  @override
  String get function => '函数';

  @override
  String get expand => '展开';

  @override
  String get largeExpansionTitle => '大量展开';

  @override
  String get sortAscending => '升序排序';

  @override
  String get sortDescending => '降序排序';

  @override
  String get inheritSort => '与上一级相同的顺序';

  @override
  String get totalsAtEnd => '总计在末尾';

  @override
  String get totalsAtStart => '总计在开头';

  @override
  String get totalsHidden => '隐藏总计';

  @override
  String get subtotalsAbove => '小计在分组上方';

  @override
  String get subtotalsBelow => '小计在分组下方';

  @override
  String get subtotalsLeft => '小计在分组左侧';

  @override
  String get subtotalsRight => '小计在分组右侧';

  @override
  String get subtotalsHidden => '隐藏小计';

  @override
  String get expandAll => '全部展开';

  @override
  String get collapseAll => '全部折叠';

  @override
  String largeExpansion(String label, int added, {required bool isRow}) =>
      '展开“$label”将添加 $added ${isRow ? '行' : '列'}。是否继续？';

  @override
  String get filter => '筛选';

  @override
  String get noFilter => '无筛选';

  @override
  String get addCondition => '添加条件';

  @override
  String get addGroup => '添加分组';

  @override
  String get addExpression => '添加表达式';

  @override
  String get matchAll => '满足所有条件';

  @override
  String get matchAny => '满足任一条件';

  @override
  String get negate => '非';

  @override
  String get opEquals => '等于';

  @override
  String get opNotEquals => '不等于';

  @override
  String get opLess => '小于';

  @override
  String get opLessOrEqual => '不大于';

  @override
  String get opGreater => '大于';

  @override
  String get opGreaterOrEqual => '不小于';

  @override
  String get opBetween => '介于';

  @override
  String get opContains => '包含';

  @override
  String get opStartsWith => '开头为';

  @override
  String get opEndsWith => '结尾为';

  @override
  String get opIsEmpty => '为空';

  @override
  String get opIsNotEmpty => '不为空';

  @override
  String get opIsOneOf => '属于';

  @override
  String get opIsTrue => '为真';

  @override
  String get opIsFalse => '为假';

  @override
  String get customFilter => '自定义筛选';

  @override
  String get expression => '表达式';

  @override
  String get selectValues => '选择值…';

  @override
  String selectedCount(int count) => '已选择 $count 项';

  @override
  String get clear => '清除';

  @override
  String get apply => '应用';

  @override
  String get column => '列';

  @override
  String get value => '值';

  @override
  String exprTypeName(ExprType type) => switch (type) {
    ExprType.number => '数字',
    ExprType.text => '文本',
    ExprType.boolean => '布尔值',
    ExprType.date => '日期',
  };

  @override
  String expressionErrorText(ExpressionErrorKind kind, List<String> a) =>
      switch (kind) {
        ExpressionErrorKind.unexpectedCharacter => '意外的字符“${a[0]}”',
        ExpressionErrorKind.unterminatedText => '文本未结束',
        ExpressionErrorKind.unterminatedName => '列名后缺少“]”',
        ExpressionErrorKind.unterminatedDate => '日期后缺少“#”',
        ExpressionErrorKind.invalidNumber => '无效的数字“${a[0]}”',
        ExpressionErrorKind.invalidDate => '无效的日期“${a[0]}”',
        ExpressionErrorKind.unexpectedToken => '意外的“${a[0]}”',
        ExpressionErrorKind.unexpectedEnd => '表达式意外结束',
        ExpressionErrorKind.unknownColumn => '未知的列“${a[0]}”',
        ExpressionErrorKind.unknownFunction => '未知的函数“${a[0]}”',
        ExpressionErrorKind.argumentCount =>
          '${a[0]} 需要 ${a[1]} 个参数，实际为 ${a[2]} 个',
        ExpressionErrorKind.argumentType =>
          '${a[0]} 的第 ${a[1]} 个参数必须是${a[2]}，而不是${a[3]}',
        ExpressionErrorKind.operandType => '${a[0]} 的操作数必须是${a[1]}，而不是${a[2]}',
        ExpressionErrorKind.incompatibleTypes => '${a[0]} 不能用于${a[1]}和${a[2]}',
        ExpressionErrorKind.unknownType => '无法确定类型',
        ExpressionErrorKind.notAllowedHere => '此处不允许使用“${a[0]}”',
        ExpressionErrorKind.resultType => '表达式必须是${a[0]}，而不是${a[1]}',
      };
}
