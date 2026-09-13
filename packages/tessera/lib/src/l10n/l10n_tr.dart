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
  String countOf(String t) => '$t sayısı';

  @override
  String distinctCountOf(String t) => '$t benzersiz değer sayısı';

  @override
  String get countLabel => 'sayı';

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
}
