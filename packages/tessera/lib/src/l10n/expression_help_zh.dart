import 'expression_help.dart';

/// zh texts of the expression help. Native review welcome.
final class ExpressionHelpStringsZh extends ExpressionHelpStrings {
  const ExpressionHelpStringsZh();

  @override
  String get languageCode => 'zh';

  @override
  String get title => '表达式帮助';

  @override
  String get tapToInsert => '点击示例、列或函数即可插入。';

  @override
  String intro(ExpressionHelpUse use) => switch (use) {
    ExpressionHelpUse.filter => '筛选保留表达式为真的行。用 and、or 和 not 组合条件。',
    ExpressionHelpUse.measure => '计算度量根据每一行的各列算出，然后像列一样求和或求平均值。',
    ExpressionHelpUse.dimension => '计算维度像列一样，按表达式的值对行分组：值可以是数字、文本、日期或布尔值。',
    ExpressionHelpUse.formula =>
      '单元格公式在数据透视表的每个单元格中，根据该单元格的聚合值'
          '（如 sum(x) 或 count）计算。',
  };

  @override
  String get examples => '示例';

  @override
  String get columns => '列';

  @override
  String get aggregates => '聚合';

  @override
  String get operators => '运算符';

  @override
  String get values => '值';

  @override
  String get rules => '规则';

  @override
  String get functions => '函数';

  @override
  String get aggregateArgument =>
      'x 是一列，或基于一行中各列的计算：sum(quantity * price)。'
      '单独的 count 统计行数。';

  @override
  String groupName(ExpressionHelpGroup group) => switch (group) {
    ExpressionHelpGroup.conditional => '条件',
    ExpressionHelpGroup.numbers => '数字',
    ExpressionHelpGroup.text => '文本',
    ExpressionHelpGroup.dates => '日期',
    ExpressionHelpGroup.other => '其他函数',
  };

  @override
  String operatorText(ExpressionHelpOperator operator) => switch (operator) {
    ExpressionHelpOperator.arithmetic => '加、减、乘、除。除以零得到空值。',
    ExpressionHelpOperator.remainder => '除法的余数：7 % 3 为 1。',
    ExpressionHelpOperator.comparison => '等于、不等于、小于、不大于、大于、不小于。也可以用 == 和 !=。',
    ExpressionHelpOperator.logic => '两个条件都满足、至少满足其一、取反。',
    ExpressionHelpOperator.inList => 'x 是所列值之一，或不是其中任何一个。',
    ExpressionHelpOperator.between => 'a ≤ x ≤ b，包含两端。',
    ExpressionHelpOperator.emptyTest => 'x 没有值，或有值。',
    ExpressionHelpOperator.dates => '日期之后或之前 n 天；两个日期之间相差的天数。',
  };

  @override
  String literalText(ExpressionHelpLiteral literal) => switch (literal) {
    ExpressionHelpLiteral.number => '数字，数字和小数点一律用半角：12.5。',
    ExpressionHelpLiteral.text =>
      '文本放在半角双引号或单引号中。文本中的引号要写两次：'
          '"say ""hi"""。',
    ExpressionHelpLiteral.date => '日期（需要时可带时间）写在两个 # 之间，年份在前。',
    ExpressionHelpLiteral.boolean => '布尔值。',
    ExpressionHelpLiteral.empty => '空值。',
    ExpressionHelpLiteral.name => '含空格或标点的列名，或与关键字拼写相同的列名，要放在方括号中。',
  };

  @override
  String ruleText(ExpressionHelpRule rule) => switch (rule) {
    ExpressionHelpRule.emptyValues =>
      '与空值进行计算或比较，结果为空：price 为空时，'
          'price * 2 和 price > 0 也为空。'
          'coalesce(price, 0) 以 0 代替空值；price is empty 找出没有 price 的行。',
    ExpressionHelpRule.filters =>
      '筛选只保留表达式为真的行：'
          'discount > 0 会去掉没有 discount 的行，'
          'discount > 0 or discount is empty 则保留这些行。',
    ExpressionHelpRule.letterCase =>
      '函数名和关键字不区分大小写（YEAR、Year 均可）；列名必须完全一致。'
          '文本比较区分大小写：要忽略大小写，请比较 lower(x)。',
  };

  @override
  ({String signature, String description}) function(
    ExpressionHelpFunction function,
  ) => switch (function) {
    ExpressionHelpFunction.ifElse => (
      signature: 'if(条件, a, b)',
      description: '条件为真时为 a，否则为 b（条件为空时也为 b）。a 与 b 须为同一类型。',
    ),
    ExpressionHelpFunction.coalesce => (
      signature: 'coalesce(a, b, …)',
      description: '第一个不为空的参数。',
    ),
    ExpressionHelpFunction.isempty => (
      signature: 'isempty(x)',
      description: 'x 为空时为真，等同于 x is empty。',
    ),
    ExpressionHelpFunction.abs => (
      signature: 'abs(x)',
      description: 'x 去掉正负号后的值。',
    ),
    ExpressionHelpFunction.round => (
      signature: 'round(x, 位数)',
      description:
          'x 舍入到小数点后 位数 位；省略 位数 时舍入为整数。'
          '位数 为负时舍入到十位、百位……：round(1234.5, -2) 为 1200。',
    ),
    ExpressionHelpFunction.floor => (
      signature: 'floor(x)',
      description: 'x 向下取整：floor(2.7) 为 2，floor(-2.5) 为 -3。',
    ),
    ExpressionHelpFunction.ceil => (
      signature: 'ceil(x)',
      description: 'x 向上取整：ceil(2.1) 为 3。',
    ),
    ExpressionHelpFunction.sqrt => (
      signature: 'sqrt(x)',
      description: 'x 的平方根；x 为负数时为空。',
    ),
    ExpressionHelpFunction.min => (
      signature: 'min(x, y, …)',
      description: '各数字中的最小值，忽略空值。',
    ),
    ExpressionHelpFunction.max => (
      signature: 'max(x, y, …)',
      description: '各数字中的最大值，忽略空值。',
    ),
    ExpressionHelpFunction.number => (
      signature: 'number(文本)',
      description: '文本中写出的数字，小数点为“.”；文本不是数字时为空。',
    ),
    ExpressionHelpFunction.len => (
      signature: 'len(文本)',
      description: '文本的字符数。',
    ),
    ExpressionHelpFunction.lower => (
      signature: 'lower(文本)',
      description: '转为小写的文本。',
    ),
    ExpressionHelpFunction.upper => (
      signature: 'upper(文本)',
      description: '转为大写的文本。',
    ),
    ExpressionHelpFunction.trim => (
      signature: 'trim(文本)',
      description: '去掉首尾空格的文本。',
    ),
    ExpressionHelpFunction.left => (
      signature: 'left(文本, n)',
      description: '文本的前 n 个字符。',
    ),
    ExpressionHelpFunction.right => (
      signature: 'right(文本, n)',
      description: '文本的后 n 个字符。',
    ),
    ExpressionHelpFunction.substring => (
      signature: 'substring(文本, 起点, 长度)',
      description: '文本中从 起点 开始的 长度 个字符，第一个字符为 1；省略 长度 时取到文本末尾。',
    ),
    ExpressionHelpFunction.contains => (
      signature: 'contains(文本, 片段)',
      description: '文本中包含 片段 时为真。',
    ),
    ExpressionHelpFunction.startswith => (
      signature: 'startswith(文本, 片段)',
      description: '文本以 片段 开头时为真。',
    ),
    ExpressionHelpFunction.endswith => (
      signature: 'endswith(文本, 片段)',
      description: '文本以 片段 结尾时为真。',
    ),
    ExpressionHelpFunction.replace => (
      signature: 'replace(文本, 旧, 新)',
      description: '把文本中所有的 旧 替换为 新 后的文本。',
    ),
    ExpressionHelpFunction.concat => (
      signature: 'concat(a, b, …)',
      description: '连接起来的各文本，忽略空值。text(x) 可将数字或日期转为文本。',
    ),
    ExpressionHelpFunction.text => (
      signature: 'text(x)',
      description:
          '数字、日期或布尔值转成的文本：text(1.5) 为 "1.5"，'
          'text(#2024-01-31#) 为 "2024-01-31"。',
    ),
    ExpressionHelpFunction.year => (
      signature: 'year(日期)',
      description: '日期的年份。',
    ),
    ExpressionHelpFunction.quarter => (
      signature: 'quarter(日期)',
      description: '一年中的季度，1 到 4。',
    ),
    ExpressionHelpFunction.month => (
      signature: 'month(日期)',
      description: '月份，1 到 12。',
    ),
    ExpressionHelpFunction.week => (
      signature: 'week(日期)',
      description: 'ISO 周数，1 到 53。',
    ),
    ExpressionHelpFunction.day => (
      signature: 'day(日期)',
      description: '一个月中的第几天，1 到 31。',
    ),
    ExpressionHelpFunction.weekday => (
      signature: 'weekday(日期)',
      description: '星期几，1（星期一）到 7（星期日）。',
    ),
    ExpressionHelpFunction.hour => (
      signature: 'hour(日期)',
      description: '时间中的小时，0 到 23。',
    ),
    ExpressionHelpFunction.dateOfText => (
      signature: 'date(文本)',
      description: '文本中写出的日期，年份在前：date("2024-01-31")；文本不是日期时为空。',
    ),
    ExpressionHelpFunction.dateOfParts => (
      signature: 'date(年, 月, 日)',
      description: '由给定的年、月、日组成的日期。',
    ),
    ExpressionHelpFunction.today => (
      signature: 'today()',
      description: '今天的日期。',
    ),
  };
}
