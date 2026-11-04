import 'expression_help.dart';

/// ja texts of the expression help. Native review welcome.
final class ExpressionHelpStringsJa extends ExpressionHelpStrings {
  const ExpressionHelpStringsJa();

  @override
  String get languageCode => 'ja';

  @override
  String get title => '式のヘルプ';

  @override
  String get tapToInsert => '例、列、関数をタップすると挿入されます。';

  @override
  String intro(ExpressionHelpUse use) => switch (use) {
    ExpressionHelpUse.filter => 'フィルターは式が真になる行を残します。条件は and、or、not で組み合わせます。',
    ExpressionHelpUse.measure => '計算メジャーは各行の列から計算され、列と同じように合計や平均が求められます。',
    ExpressionHelpUse.dimension =>
      '計算ディメンションは、列と同じように式の値で行をグループ化します。'
          '値は数値、テキスト、日付、真偽値のいずれかです。',
    ExpressionHelpUse.formula =>
      'セルの数式は、ピボットテーブルの各セルで、そのセルの集計値'
          '（sum(x) や count など）から計算されます。',
  };

  @override
  String get examples => '例';

  @override
  String get columns => '列';

  @override
  String get aggregates => '集計';

  @override
  String get operators => '演算子';

  @override
  String get values => '値';

  @override
  String get rules => 'ルール';

  @override
  String get functions => '関数';

  @override
  String get aggregateArgument =>
      'x は列、または 1 行の列から求める計算です：sum(quantity * price)。'
      'count だけなら行数を数えます。';

  @override
  String groupName(ExpressionHelpGroup group) => switch (group) {
    ExpressionHelpGroup.conditional => '条件',
    ExpressionHelpGroup.numbers => '数値',
    ExpressionHelpGroup.text => 'テキスト',
    ExpressionHelpGroup.dates => '日付',
    ExpressionHelpGroup.other => 'その他の関数',
  };

  @override
  String operatorText(ExpressionHelpOperator operator) => switch (operator) {
    ExpressionHelpOperator.arithmetic => '加算、減算、乗算、除算。0 で割ると空の値になります。',
    ExpressionHelpOperator.remainder => '割り算の余り：7 % 3 は 1。',
    ExpressionHelpOperator.comparison =>
      '等しい、等しくない、より小さい、以下、より大きい、以上。== と != も使えます。',
    ExpressionHelpOperator.logic => '両方の条件を満たす、いずれかを満たす、否定。',
    ExpressionHelpOperator.inList => 'x が列挙した値のいずれかである、またはどれでもない。',
    ExpressionHelpOperator.between => 'a ≤ x ≤ b（両端を含む）。',
    ExpressionHelpOperator.emptyTest => 'x に値がない、または値がある。',
    ExpressionHelpOperator.dates => '日付の n 日後または n 日前。2 つの日付の間の日数。',
  };

  @override
  String literalText(ExpressionHelpLiteral literal) => switch (literal) {
    ExpressionHelpLiteral.number => '数値。数字と小数点は常に半角で書きます：12.5。',
    ExpressionHelpLiteral.text =>
      'テキストは半角の二重引用符または一重引用符で囲みます。'
          '中の引用符は 2 つ重ねます："say ""hi"""。',
    ExpressionHelpLiteral.date => '日付（必要なら時刻も）を # で囲みます。年を先頭に書きます。',
    ExpressionHelpLiteral.boolean => '真偽値。',
    ExpressionHelpLiteral.empty => '空の値。',
    ExpressionHelpLiteral.name => 'スペースや記号を含む列名、またはキーワードと同じ綴りの列名は角かっこで囲みます。',
  };

  @override
  String ruleText(ExpressionHelpRule rule) => switch (rule) {
    ExpressionHelpRule.emptyValues =>
      '空の値を含む計算や比較の結果は空になります：price が空の行では '
          'price * 2 も price > 0 も空です。'
          'coalesce(price, 0) は代わりに 0 を使います。'
          'price is empty は price のない行を見つけます。',
    ExpressionHelpRule.filters =>
      'フィルターは式が真の行だけを残します：'
          'discount > 0 は discount のない行を除外し、'
          'discount > 0 or discount is empty はそれらの行も残します。',
    ExpressionHelpRule.letterCase =>
      '関数名とキーワードは大文字でも小文字でもかまいません（YEAR、Year）。'
          '列名は完全に一致する必要があります。'
          'テキストの比較では大文字と小文字が区別されます：'
          '区別しないなら lower(x) を比較します。',
  };

  @override
  ({String signature, String description}) function(
    ExpressionHelpFunction function,
  ) => switch (function) {
    ExpressionHelpFunction.ifElse => (
      signature: 'if(条件, a, b)',
      description: '条件が真なら a、それ以外は b（条件が空の場合も b）。a と b は同じ型です。',
    ),
    ExpressionHelpFunction.coalesce => (
      signature: 'coalesce(a, b, …)',
      description: '空でない最初の引数。',
    ),
    ExpressionHelpFunction.isempty => (
      signature: 'isempty(x)',
      description: 'x が空なら真。x is empty と同じです。',
    ),
    ExpressionHelpFunction.abs => (
      signature: 'abs(x)',
      description: 'x から符号を取り除いた値。',
    ),
    ExpressionHelpFunction.round => (
      signature: 'round(x, 桁数)',
      description:
          'x を小数点以下 桁数 桁に丸めた値。桁数 を省略すると整数に丸めます。'
          '桁数 が負なら 10 の位、100 の位…に丸めます：round(1234.5, -2) は 1200。',
    ),
    ExpressionHelpFunction.floor => (
      signature: 'floor(x)',
      description: 'x を整数に切り下げた値：floor(2.7) は 2、floor(-2.5) は -3。',
    ),
    ExpressionHelpFunction.ceil => (
      signature: 'ceil(x)',
      description: 'x を整数に切り上げた値：ceil(2.1) は 3。',
    ),
    ExpressionHelpFunction.sqrt => (
      signature: 'sqrt(x)',
      description: 'x の平方根。x が負なら空。',
    ),
    ExpressionHelpFunction.min => (
      signature: 'min(x, y, …)',
      description: '数値のうち最小のもの（空の値は除く）。',
    ),
    ExpressionHelpFunction.max => (
      signature: 'max(x, y, …)',
      description: '数値のうち最大のもの（空の値は除く）。',
    ),
    ExpressionHelpFunction.number => (
      signature: 'number(テキスト)',
      description: 'テキストに書かれた数値（小数点は「.」）。テキストが数値でなければ空。',
    ),
    ExpressionHelpFunction.len => (
      signature: 'len(テキスト)',
      description: 'テキストの文字数。',
    ),
    ExpressionHelpFunction.lower => (
      signature: 'lower(テキスト)',
      description: 'テキストを小文字にしたもの。',
    ),
    ExpressionHelpFunction.upper => (
      signature: 'upper(テキスト)',
      description: 'テキストを大文字にしたもの。',
    ),
    ExpressionHelpFunction.trim => (
      signature: 'trim(テキスト)',
      description: '先頭と末尾の空白を除いたテキスト。',
    ),
    ExpressionHelpFunction.left => (
      signature: 'left(テキスト, n)',
      description: 'テキストの先頭 n 文字。',
    ),
    ExpressionHelpFunction.right => (
      signature: 'right(テキスト, n)',
      description: 'テキストの末尾 n 文字。',
    ),
    ExpressionHelpFunction.substring => (
      signature: 'substring(テキスト, 位置, 長さ)',
      description:
          'テキストの 位置 番目の文字から 長さ 文字分（最初の文字が 1 番目）。'
          '長さ を省略するとテキストの最後まで。',
    ),
    ExpressionHelpFunction.contains => (
      signature: 'contains(テキスト, 部分)',
      description: 'テキストに 部分 が含まれていれば真。',
    ),
    ExpressionHelpFunction.startswith => (
      signature: 'startswith(テキスト, 部分)',
      description: 'テキストが 部分 で始まれば真。',
    ),
    ExpressionHelpFunction.endswith => (
      signature: 'endswith(テキスト, 部分)',
      description: 'テキストが 部分 で終われば真。',
    ),
    ExpressionHelpFunction.replace => (
      signature: 'replace(テキスト, 旧, 新)',
      description: 'テキスト中のすべての 旧 を 新 に置き換えたもの。',
    ),
    ExpressionHelpFunction.concat => (
      signature: 'concat(a, b, …)',
      description: 'テキストを連結したもの（空の値は除く）。数値や日付は text(x) でテキストにします。',
    ),
    ExpressionHelpFunction.text => (
      signature: 'text(x)',
      description:
          '数値、日付、真偽値をテキストにしたもの：text(1.5) は "1.5"、'
          'text(#2024-01-31#) は "2024-01-31"。',
    ),
    ExpressionHelpFunction.year => (
      signature: 'year(日付)',
      description: '日付の年。',
    ),
    ExpressionHelpFunction.quarter => (
      signature: 'quarter(日付)',
      description: '四半期（1～4）。',
    ),
    ExpressionHelpFunction.month => (
      signature: 'month(日付)',
      description: '月（1～12）。',
    ),
    ExpressionHelpFunction.week => (
      signature: 'week(日付)',
      description: 'ISO 週番号（1～53）。',
    ),
    ExpressionHelpFunction.day => (
      signature: 'day(日付)',
      description: '月内の日（1～31）。',
    ),
    ExpressionHelpFunction.weekday => (
      signature: 'weekday(日付)',
      description: '曜日。1（月曜日）～7（日曜日）。',
    ),
    ExpressionHelpFunction.hour => (
      signature: 'hour(日付)',
      description: '時刻の時（0～23）。',
    ),
    ExpressionHelpFunction.dateOfText => (
      signature: 'date(テキスト)',
      description:
          'テキストに書かれた日付（年が先頭）：date("2024-01-31")。'
          'テキストが日付でなければ空。',
    ),
    ExpressionHelpFunction.dateOfParts => (
      signature: 'date(年, 月, 日)',
      description: '指定した年、月、日の日付。',
    ),
    ExpressionHelpFunction.today => (
      signature: 'today()',
      description: '今日の日付。',
    ),
  };
}
