import 'expression_help.dart';

/// tr texts of the expression help. Native review welcome.
final class ExpressionHelpStringsTr extends ExpressionHelpStrings {
  const ExpressionHelpStringsTr();

  @override
  String get languageCode => 'tr';

  @override
  String get title => 'İfade yardımı';

  @override
  String get tapToInsert =>
      'Eklemek için bir örneğe, sütuna ya da işleve dokunun.';

  @override
  String intro(ExpressionHelpUse use) => switch (use) {
    ExpressionHelpUse.filter =>
      'Filtre, ifadenin doğru olduğu satırları tutar. Koşullar and, '
          'or ve not ile birleştirilir.',
    ExpressionHelpUse.measure =>
      'Hesaplanan ölçü, her satır için o satırın sütunlarından '
          'hesaplanır, sonra bir sütun gibi toplanır ya da ortalaması '
          'alınır.',
    ExpressionHelpUse.dimension =>
      'Hesaplanan boyut, satırları bir sütun gibi ifadenin değerine '
          'göre gruplar: sayı, metin, tarih ya da doğru/yanlış.',
    ExpressionHelpUse.formula =>
      'Hücre formülü, pivot tablonun her hücresinde o hücrenin '
          'özetlerinden hesaplanır; örneğin sum(x) veya count.',
  };

  @override
  String get examples => 'Örnekler';

  @override
  String get columns => 'Sütunlar';

  @override
  String get aggregates => 'Özetler';

  @override
  String get operators => 'İşleçler';

  @override
  String get values => 'Değerler';

  @override
  String get rules => 'Kurallar';

  @override
  String get functions => 'İşlevler';

  @override
  String get aggregateArgument =>
      'x bir sütun ya da bir satırın sütunları üzerinden yapılan bir '
      'hesaplamadır: sum(quantity * price). Tek başına count '
      'satırları sayar.';

  @override
  String groupName(ExpressionHelpGroup group) => switch (group) {
    ExpressionHelpGroup.conditional => 'Koşullar',
    ExpressionHelpGroup.numbers => 'Sayılar',
    ExpressionHelpGroup.text => 'Metin',
    ExpressionHelpGroup.dates => 'Tarihler',
    ExpressionHelpGroup.other => 'Diğer işlevler',
  };

  @override
  String operatorText(ExpressionHelpOperator operator) => switch (operator) {
    ExpressionHelpOperator.arithmetic =>
      'Toplama, çıkarma, çarpma, bölme. Sıfıra bölmek boş değer '
          'verir.',
    ExpressionHelpOperator.remainder =>
      'Bölme işleminden kalan: 7 % 3 sonucu 1.',
    ExpressionHelpOperator.comparison =>
      'Eşit, eşit değil, küçük, küçük ya da eşit, büyük, büyük ya da '
          'eşit. == ve != de çalışır.',
    ExpressionHelpOperator.logic => 'İki koşul birden, ikisinden biri, tersi.',
    ExpressionHelpOperator.inList =>
      'x, listelenen değerlerden biridir ya da hiçbiri değildir.',
    ExpressionHelpOperator.between => 'a ≤ x ≤ b, iki uç da dahil.',
    ExpressionHelpOperator.emptyTest => 'x boştur ya da bir değeri vardır.',
    ExpressionHelpOperator.dates =>
      'Bir tarihten n gün sonrası ya da öncesi; iki tarih arasındaki '
          'gün sayısı.',
  };

  @override
  String literalText(ExpressionHelpLiteral literal) => switch (literal) {
    ExpressionHelpLiteral.number =>
      'Sayılar, her zaman ondalık noktayla: 12.5, 12,5 değil.',
    ExpressionHelpLiteral.text =>
      'Çift ya da tek tırnak içinde metin. İçerideki tırnak iki kez '
          'yazılır: "say ""hi""".',
    ExpressionHelpLiteral.date =>
      'Tarihler, gerekirse saatiyle, # işaretleri arasında, önce yıl.',
    ExpressionHelpLiteral.boolean => 'Mantıksal değerler.',
    ExpressionHelpLiteral.empty => 'Boş değer.',
    ExpressionHelpLiteral.name =>
      'Boşluk ya da noktalama işareti içeren veya bir anahtar sözcük '
          'gibi yazılan sütun adı köşeli parantez içine alınır.',
  };

  @override
  String ruleText(ExpressionHelpRule rule) => switch (rule) {
    ExpressionHelpRule.emptyValues =>
      'Boş bir değerle yapılan hesaplama ya da karşılaştırma boştur: '
          'price sütununun boş olduğu satırlarda price * 2 ve price > 0 '
          'da boştur. coalesce(price, 0) boş değer yerine 0 kullanır; '
          'price is empty fiyatı olmayan satırları bulur.',
    ExpressionHelpRule.filters =>
      'Filtre bir satırı yalnızca ifadesi doğruysa tutar: discount > '
          '0 indirimsiz satırları atar, discount > 0 or discount is '
          'empty ise onları tutar.',
    ExpressionHelpRule.letterCase =>
      'İşlev adları ve anahtar sözcükler büyük ya da küçük harfle '
          'yazılabilir (YEAR, Year); sütun adları ise tam olarak '
          'eşleşmelidir. Metin karşılaştırmaları büyük/küçük harfe '
          'duyarlıdır: harf büyüklüğünü yok saymak için lower(x) '
          'sonucunu karşılaştırın.',
  };

  @override
  ({String signature, String description}) function(
    ExpressionHelpFunction function,
  ) => switch (function) {
    ExpressionHelpFunction.ifElse => (
      signature: 'if(koşul, a, b)',
      description:
          'Koşul doğruysa a, değilse b (koşul boşsa da b). a ile b aynı '
          'türdendir.',
    ),
    ExpressionHelpFunction.coalesce => (
      signature: 'coalesce(a, b, …)',
      description: 'Argümanlardan boş olmayan ilki.',
    ),
    ExpressionHelpFunction.isempty => (
      signature: 'isempty(x)',
      description: 'x boşsa doğru; x is empty ile aynı.',
    ),
    ExpressionHelpFunction.abs => (
      signature: 'abs(x)',
      description: 'x, işareti olmadan.',
    ),
    ExpressionHelpFunction.round => (
      signature: 'round(x, basamak)',
      description:
          'x, basamak kadar ondalık basamağa yuvarlanır; basamak '
          'verilmezse tam sayıya. Negatif basamak onluğa, yüzlüğe… '
          'yuvarlar: round(1234.5, -2) sonucu 1200.',
    ),
    ExpressionHelpFunction.floor => (
      signature: 'floor(x)',
      description:
          'x aşağı doğru tam sayıya yuvarlanır: floor(2.7) sonucu 2, '
          'floor(-2.5) sonucu -3.',
    ),
    ExpressionHelpFunction.ceil => (
      signature: 'ceil(x)',
      description: 'x yukarı doğru tam sayıya yuvarlanır: ceil(2.1) sonucu 3.',
    ),
    ExpressionHelpFunction.sqrt => (
      signature: 'sqrt(x)',
      description: 'x değerinin karekökü; x negatifse boş.',
    ),
    ExpressionHelpFunction.min => (
      signature: 'min(x, y, …)',
      description: 'Sayıların en küçüğü; boş olanlar atlanır.',
    ),
    ExpressionHelpFunction.max => (
      signature: 'max(x, y, …)',
      description: 'Sayıların en büyüğü; boş olanlar atlanır.',
    ),
    ExpressionHelpFunction.number => (
      signature: 'number(metin)',
      description:
          'Metinde ondalık noktayla yazılmış sayı; metin bir sayı '
          'değilse boş.',
    ),
    ExpressionHelpFunction.len => (
      signature: 'len(metin)',
      description: 'Metindeki karakter sayısı.',
    ),
    ExpressionHelpFunction.lower => (
      signature: 'lower(metin)',
      description: 'Küçük harfe çevrilmiş metin.',
    ),
    ExpressionHelpFunction.upper => (
      signature: 'upper(metin)',
      description: 'Büyük harfe çevrilmiş metin.',
    ),
    ExpressionHelpFunction.trim => (
      signature: 'trim(metin)',
      description: 'Başındaki ve sonundaki boşluklar atılmış metin.',
    ),
    ExpressionHelpFunction.left => (
      signature: 'left(metin, n)',
      description: 'Metindeki ilk n karakter.',
    ),
    ExpressionHelpFunction.right => (
      signature: 'right(metin, n)',
      description: 'Metindeki son n karakter.',
    ),
    ExpressionHelpFunction.substring => (
      signature: 'substring(metin, başlangıç, uzunluk)',
      description:
          'Metinde başlangıç konumundan itibaren uzunluk kadar karakter '
          '(ilk karakter 1); uzunluk verilmezse metnin geri kalanı.',
    ),
    ExpressionHelpFunction.contains => (
      signature: 'contains(metin, parça)',
      description: 'Metinde parça geçiyorsa doğru.',
    ),
    ExpressionHelpFunction.startswith => (
      signature: 'startswith(metin, parça)',
      description: 'Metin parça ile başlıyorsa doğru.',
    ),
    ExpressionHelpFunction.endswith => (
      signature: 'endswith(metin, parça)',
      description: 'Metin parça ile bitiyorsa doğru.',
    ),
    ExpressionHelpFunction.replace => (
      signature: 'replace(metin, eski, yeni)',
      description: 'Her eski yerine yeni yazılmış metin.',
    ),
    ExpressionHelpFunction.concat => (
      signature: 'concat(a, b, …)',
      description:
          'Boş olanlar atlanarak birleştirilmiş metinler. text(x) bir '
          'sayıyı ya da tarihi metne çevirir.',
    ),
    ExpressionHelpFunction.text => (
      signature: 'text(x)',
      description:
          'Bir sayı, tarih ya da doğru/yanlış değeri metin olarak: '
          'text(1.5) sonucu "1.5", text(#2024-01-31#) sonucu '
          '"2024-01-31".',
    ),
    ExpressionHelpFunction.year => (
      signature: 'year(tarih)',
      description: 'Tarihin yılı.',
    ),
    ExpressionHelpFunction.quarter => (
      signature: 'quarter(tarih)',
      description: 'Yılın çeyreği, 1 ile 4 arası.',
    ),
    ExpressionHelpFunction.month => (
      signature: 'month(tarih)',
      description: 'Ay, 1 ile 12 arası.',
    ),
    ExpressionHelpFunction.week => (
      signature: 'week(tarih)',
      description: 'ISO hafta numarası, 1 ile 53 arası.',
    ),
    ExpressionHelpFunction.day => (
      signature: 'day(tarih)',
      description: 'Ayın günü, 1 ile 31 arası.',
    ),
    ExpressionHelpFunction.weekday => (
      signature: 'weekday(tarih)',
      description: 'Haftanın günü, 1 (Pazartesi) ile 7 (Pazar) arası.',
    ),
    ExpressionHelpFunction.hour => (
      signature: 'hour(tarih)',
      description: 'Saat, 0 ile 23 arası.',
    ),
    ExpressionHelpFunction.dateOfText => (
      signature: 'date(metin)',
      description:
          'Metinde yazılı tarih, önce yıl: date("2024-01-31"); metin bir '
          'tarih değilse boş.',
    ),
    ExpressionHelpFunction.dateOfParts => (
      signature: 'date(yıl, ay, gün)',
      description: 'Verilen yıl, ay ve günden oluşan tarih.',
    ),
    ExpressionHelpFunction.today => (
      signature: 'today()',
      description: 'Bugünün tarihi.',
    ),
  };
}
