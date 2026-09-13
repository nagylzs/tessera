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
  String countOf(String t) => '$t的计数';

  @override
  String distinctCountOf(String t) => '$t的唯一值数';

  @override
  String get countLabel => '计数';

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
  String get expandAll => '全部展开';

  @override
  String get collapseAll => '全部折叠';

  @override
  String largeExpansion(String label, int added, {required bool isRow}) =>
      '展开“$label”将添加 $added ${isRow ? '行' : '列'}。是否继续？';
}
