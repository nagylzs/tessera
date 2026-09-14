import '../cube/layout_aggregate.dart';
import '../expr/expr_type.dart';
import '../expr/expression_error.dart';
import '../facts/dimension.dart';
import 'tessera_strings.dart';

/// tr texts. Native review welcome.
final class TesseraStringsTr extends TesseraStrings {
  const TesseraStringsTr();

  @override
  String get languageCode => 'tr';

  @override
  String sumOf(String t) => '$t toplamı';

  @override
  String averageOf(String t) => '$t ortalaması';

  @override
  String minimumOf(String t) => '$t minimumu';

  @override
  String maximumOf(String t) => '$t maksimumu';

  @override
  String stdDevOf(String t) => '$t standart sapması';

  @override
  String stdDevPopulationOf(String t) => '$t popülasyon standart sapması';

  @override
  String varianceOf(String t) => '$t varyansı';

  @override
  String variancePopulationOf(String t) => '$t popülasyon varyansı';

  @override
  String countOf(String t) => '$t sayısı';

  @override
  String distinctCountOf(String t) => '$t benzersiz değer sayısı';

  @override
  String get countLabel => 'sayı';

  @override
  String percentOfTotal(String base, TotalOf of) => switch (of) {
    TotalOf.row => '$base satır toplamının %’si',
    TotalOf.column => '$base sütun toplamının %’si',
    TotalOf.grand => '$base genel toplamın %’si',
    TotalOf.parentRow => '$base üst satırın %’si',
    TotalOf.parentColumn => '$base üst sütunun %’si',
  };

  @override
  String differenceFrom(String base, String item, {required bool percent}) =>
      percent ? '$base % fark: $item' : '$base fark: $item';

  @override
  String get previousItem => 'önceki';

  @override
  String get nextItem => 'sonraki';

  @override
  String runningTotalOf(String base) => '$base kümülatif toplam';

  @override
  String rankOf(String base) => '$base sıra';

  @override
  String get countOfFacts => 'Satır sayısı';

  @override
  String get sum => 'Toplam';

  @override
  String get average => 'Ortalama';

  @override
  String get minimum => 'Minimum';

  @override
  String get maximum => 'Maksimum';

  @override
  String get standardDeviation => 'Standart sapma';

  @override
  String get populationStandardDeviation => 'Popülasyon standart sapması';

  @override
  String get variance => 'Varyans';

  @override
  String get populationVariance => 'Popülasyon varyansı';

  @override
  String get countOfValues => 'Değer sayısı';

  @override
  String get distinctCount => 'Benzersiz değer sayısı';

  @override
  String datePartName(DatePart part) => switch (part) {
    DatePart.year => 'yıl',
    DatePart.quarter => 'çeyrek',
    DatePart.month => 'ay',
    DatePart.week => 'hafta',
    DatePart.day => 'gün',
    DatePart.weekday => 'haftanın günü',
    DatePart.hour => 'saat',
  };

  @override
  String datePartLabel(String column, DatePart part) {
    final p = datePartName(part);
    return '$column $p';
  }

  static const _months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  static const _weekdays = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  @override
  String monthName(int month) => _months[month - 1];

  @override
  String weekdayName(int weekday) => _weekdays[weekday - 1];

  @override
  String quarter(int q) => 'Ç$q';

  @override
  String get decimalSeparator => ',';

  @override
  String get groupSeparator => '.';

  @override
  String get rows => 'Satırlar';

  @override
  String get columns => 'Sütunlar';

  @override
  String get values => 'Değerler';

  @override
  String get emptyGroup => '(boş)';

  @override
  String get total => 'Toplam';

  @override
  String get dropDimensionsHere => 'Boyutları buraya bırakın';

  @override
  String get addDimension => 'Boyut ekle';

  @override
  String get addAggregate => 'Özet ekle';

  @override
  String get search => 'Ara';

  @override
  String get alreadyInUse => 'zaten kullanımda';

  @override
  String get function => 'İşlev';

  @override
  String get expand => 'Genişlet';

  @override
  String get largeExpansionTitle => 'Büyük genişletme';

  @override
  String get sortAscending => 'Artan sırala';

  @override
  String get sortDescending => 'Azalan sırala';

  @override
  String get inheritSort => 'Üst düzeyle aynı sıralama';

  @override
  String get totalsAtEnd => 'Toplamlar sonda';

  @override
  String get totalsAtStart => 'Toplamlar başta';

  @override
  String get totalsHidden => 'Toplamları gizle';

  @override
  String get subtotalsAbove => 'Ara toplamlar grubun üstünde';

  @override
  String get subtotalsBelow => 'Ara toplamlar grubun altında';

  @override
  String get subtotalsLeft => 'Ara toplamlar grubun solunda';

  @override
  String get subtotalsRight => 'Ara toplamlar grubun sağında';

  @override
  String get subtotalsHidden => 'Ara toplamları gizle';

  @override
  String get expandAll => 'Tümünü genişlet';

  @override
  String get collapseAll => 'Tümünü daralt';

  @override
  String largeExpansion(String label, int added, {required bool isRow}) =>
      '"$label" genişletildiğinde $added ${isRow ? 'satır' : 'sütun'} eklenir. Devam edilsin mi?';

  @override
  String get filter => 'Filtre';

  @override
  String get noFilter => 'Filtre yok';

  @override
  String get addCondition => 'Koşul ekle';

  @override
  String get addGroup => 'Grup ekle';

  @override
  String get addExpression => 'İfade ekle';

  @override
  String get matchAll => 'Tüm koşullar';

  @override
  String get matchAny => 'Koşullardan herhangi biri';

  @override
  String get negate => 'Değil';

  @override
  String get opEquals => 'eşittir';

  @override
  String get opNotEquals => 'eşit değildir';

  @override
  String get opLess => 'küçüktür';

  @override
  String get opLessOrEqual => 'en fazla';

  @override
  String get opGreater => 'büyüktür';

  @override
  String get opGreaterOrEqual => 'en az';

  @override
  String get opBetween => 'arasında';

  @override
  String get opContains => 'içerir';

  @override
  String get opStartsWith => 'ile başlar';

  @override
  String get opEndsWith => 'ile biter';

  @override
  String get opIsEmpty => 'boş';

  @override
  String get opIsNotEmpty => 'boş değil';

  @override
  String get opIsOneOf => 'şunlardan biri';

  @override
  String get opIsTrue => 'doğru';

  @override
  String get opIsFalse => 'yanlış';

  @override
  String get customFilter => 'Özel filtre';

  @override
  String get expression => 'İfade';

  @override
  String get selectValues => 'Değer seç…';

  @override
  String selectedCount(int count) => '$count seçildi';

  @override
  String get clear => 'Temizle';

  @override
  String get apply => 'Uygula';

  @override
  String get column => 'Sütun';

  @override
  String get value => 'Değer';

  @override
  String exprTypeName(ExprType type) => switch (type) {
    ExprType.number => 'sayı',
    ExprType.text => 'metin',
    ExprType.boolean => 'mantıksal',
    ExprType.date => 'tarih',
  };

  @override
  String expressionErrorText(ExpressionErrorKind kind, List<String> a) =>
      switch (kind) {
        ExpressionErrorKind.unexpectedCharacter =>
          'beklenmeyen karakter "${a[0]}"',
        ExpressionErrorKind.unterminatedText => 'metin kapatılmamış',
        ExpressionErrorKind.unterminatedName => 'sütun adından sonra "]" eksik',
        ExpressionErrorKind.unterminatedDate => 'tarihten sonra "#" eksik',
        ExpressionErrorKind.invalidNumber => 'geçersiz sayı "${a[0]}"',
        ExpressionErrorKind.invalidDate => 'geçersiz tarih "${a[0]}"',
        ExpressionErrorKind.unexpectedToken => 'beklenmeyen "${a[0]}"',
        ExpressionErrorKind.unexpectedEnd => 'ifade beklenmedik şekilde bitti',
        ExpressionErrorKind.unknownColumn => 'bilinmeyen sütun "${a[0]}"',
        ExpressionErrorKind.unknownFunction => 'bilinmeyen işlev "${a[0]}"',
        ExpressionErrorKind.argumentCount =>
          '${a[0]} ${a[1]} argüman bekler, ${a[2]} verildi',
        ExpressionErrorKind.argumentType =>
          '${a[0]} işlevinin ${a[1]}. argümanı ${a[3]} değil ${a[2]} olmalı',
        ExpressionErrorKind.operandType =>
          '${a[0]} işleminin operandı ${a[2]} değil ${a[1]} olmalı',
        ExpressionErrorKind.incompatibleTypes =>
          '${a[0]}, ${a[1]} ve ${a[2]} için uygulanamaz',
        ExpressionErrorKind.unknownType => 'tür belirlenemiyor',
        ExpressionErrorKind.notAllowedHere => '"${a[0]}" burada kullanılamaz',
        ExpressionErrorKind.resultType => 'ifade ${a[1]} değil ${a[0]} olmalı',
      };
}
