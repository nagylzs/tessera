import 'package:test/test.dart';
import 'package:tessera/tessera.dart';

/// The parameters of a signature such as `round(x, digits)` or
/// `min(x, y, …)`: their number, `…` not counted.
int parameterCount(String signature) {
  final inside = signature.substring(
    signature.indexOf('(') + 1,
    signature.lastIndexOf(')'),
  );
  return inside.trim().isEmpty
      ? 0
      : inside.split(',').where((p) => p.trim() != '…').length;
}

void main() {
  test('every built-in locale has its own expression help', () {
    for (final l in builtInStrings.values) {
      expect(l.expressionHelp.languageCode, l.languageCode);
    }
  });

  test('the help lists every built-in function', () {
    final listed = {
      for (final f in ExpressionHelpFunction.values) f.functionName,
    };
    final builtIn = {
      for (final f in FunctionRegistry.standard().functions) f.name,
      'if',
      'coalesce',
      'isempty',
    };
    expect(listed, builtIn);
  });

  test('each form takes as many arguments as its signature shows', () {
    const en = ExpressionHelpStringsEn();
    final registry = FunctionRegistry.standard();
    for (final f in ExpressionHelpFunction.values) {
      final signature = en.function(f).signature;
      final n = parameterCount(signature);
      expect(n > 0, f.hasParameters, reason: signature);
      if (f.group == ExpressionHelpGroup.conditional) continue;
      expect(
        registry.lookup(f.functionName).any((g) => g.acceptsCount(n)),
        isTrue,
        reason: signature,
      );
    }
  });

  test('every locale fills in every text', () {
    for (final l in builtInStrings.values) {
      final h = l.expressionHelp;
      final tag = h.languageCode;
      final texts = [
        h.title,
        h.tapToInsert,
        h.examples,
        h.columns,
        h.aggregates,
        h.operators,
        h.values,
        h.rules,
        h.functions,
        h.aggregateArgument,
        ...ExpressionHelpUse.values.map(h.intro),
        ...ExpressionHelpGroup.values.map(h.groupName),
        ...ExpressionHelpOperator.values.map(h.operatorText),
        ...ExpressionHelpLiteral.values.map(h.literalText),
        ...ExpressionHelpRule.values.map(h.ruleText),
      ];
      for (final t in texts) {
        expect(t.trim(), isNotEmpty, reason: tag);
      }
      for (final f in ExpressionHelpFunction.values) {
        final (:signature, :description) = h.function(f);
        expect(
          signature,
          startsWith('${f.functionName}('),
          reason: '$tag $signature',
        );
        expect(signature, endsWith(')'), reason: '$tag $signature');
        expect(
          parameterCount(signature),
          parameterCount(const ExpressionHelpStringsEn().function(f).signature),
          reason: '$tag $signature',
        );
        expect(description.trim(), isNotEmpty, reason: '$tag $signature');
      }
    }
  });

  test('the aggregates are those a cell formula knows', () {
    final scope = ExpressionScope.cells({'x': ExprType.number});
    for (final a in ExpressionHelpAggregate.values) {
      expect(
        Expression.validate(a.syntax, scope: scope, expected: ExprType.number),
        isNull,
        reason: a.syntax,
      );
    }
  });

  test('the use follows the scope and the expected type', () {
    const rows = ExpressionScope.rows({'x': ExprType.number});
    const cells = ExpressionScope.cells({'x': ExprType.number});
    expect(
      ExpressionHelpUse.of(rows, ExprType.boolean),
      ExpressionHelpUse.filter,
    );
    expect(
      ExpressionHelpUse.of(rows, ExprType.number),
      ExpressionHelpUse.measure,
    );
    expect(ExpressionHelpUse.of(rows, null), ExpressionHelpUse.dimension);
    expect(
      ExpressionHelpUse.of(cells, ExprType.number),
      ExpressionHelpUse.formula,
    );
  });
}
