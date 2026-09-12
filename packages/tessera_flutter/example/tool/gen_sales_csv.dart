// Generates assets/sales.csv — deterministic sample data for the example app
// (and the same file for the engine's tests, packages/tessera/test/data/).
//
// Run from the example directory:
//   dart run tool/gen_sales_csv.dart
//
// The data is designed to exercise grouping/aggregation edge cases:
//   * hierarchical dimensions: country -> region, product -> category
//   * some countries have no region, some products have no category
//   * some rows carry only a region (no country, category or product)
//   * some rows carry a category but no product
//   * quantity / unit_price are sometimes empty; total is then empty too
//   * discount and salesperson are sometimes empty
import 'dart:io';
import 'dart:math';

const rowCount_ = 1000;
const seed = 42;

// country -> region (null = country without a region)
const countries = <String, String?>{
  'Germany': 'Europe',
  'France': 'Europe',
  'Hungary': 'Europe',
  'United Kingdom': 'Europe',
  'Poland': 'Europe',
  'United States': 'North America',
  'Canada': 'North America',
  'Mexico': 'North America',
  'Japan': 'Asia',
  'China': 'Asia',
  'India': 'Asia',
  'South Korea': 'Asia',
  'Brazil': 'South America',
  'Argentina': 'South America',
  'South Africa': 'Africa',
  'Egypt': 'Africa',
  'Australia': 'Oceania',
  'New Zealand': 'Oceania',
  'Iceland': null,
  'Singapore': null,
};

// product -> (category, base price); null category = product without a category
const products = <String, (String?, double)>{
  'Laptop': ('Electronics', 1200),
  'Monitor': ('Electronics', 350),
  'Keyboard': ('Electronics', 60),
  'Mouse': ('Electronics', 25),
  'Headphones': ('Electronics', 90),
  'Desk': ('Furniture', 400),
  'Office Chair': ('Furniture', 250),
  'Bookshelf': ('Furniture', 180),
  'Desk Lamp': ('Furniture', 45),
  'Printer Paper': ('Office Supplies', 8),
  'Pens': ('Office Supplies', 4),
  'Stapler': ('Office Supplies', 12),
  'Binder': ('Office Supplies', 6),
  'Antivirus': ('Software', 50),
  'Office Suite': ('Software', 150),
  'IDE License': ('Software', 200),
  'Gift Card': (null, 100),
  'Extended Warranty': (null, 80),
  'Shipping': (null, 15),
};

const salespeople = [
  'Kovács Anna',
  'Nagy Péter',
  'Szabó Éva',
  'John Smith',
  'Emily Johnson',
  'Hans Müller',
  'Marie Dubois',
  'Yuki Tanaka',
  'Priya Sharma',
  'Carlos García',
];

// Probabilities for the various "missing" cases.
const pRegionOnly = 0.05; // region set, country/category/product empty
const pCategoryOnly = 0.05; // category set, product empty
const pNoQuantity = 0.04;
const pNoUnitPrice = 0.04;
const pNoDiscount = 0.15;
const pNoSalesperson = 0.03;

void main(List<String> args) {
  // Optional: `--rows N --out path` for benchmarking with bigger files.
  var rowCount = rowCount_;
  var outPaths = ['assets/sales.csv', '../../tessera/test/data/sales.csv'];
  for (var i = 0; i + 1 < args.length; i += 2) {
    if (args[i] == '--rows') rowCount = int.parse(args[i + 1]);
    if (args[i] == '--out') outPaths = [args[i + 1]];
  }
  final rnd = Random(seed);
  final regions = countries.values.whereType<String>().toSet().toList()..sort();
  final categories =
      products.values.map((p) => p.$1).whereType<String>().toSet().toList()
        ..sort();
  final countryNames = countries.keys.toList();
  final productNames = products.keys.toList();

  T pick<T>(List<T> list) => list[rnd.nextInt(list.length)];
  bool chance(double p) => rnd.nextDouble() < p;
  String money(double v) => v.toStringAsFixed(2);

  final start = DateTime.utc(2024, 1, 1);
  const dayRange = 731; // 2024-01-01 .. 2025-12-31

  final rows = <List<String?>>[];
  for (var id = 1; id <= rowCount; id++) {
    String? region;
    String? country;
    String? category;
    String? product;
    double basePrice;

    if (chance(pRegionOnly)) {
      region = pick(regions);
      basePrice = 50 + rnd.nextDouble() * 500;
    } else {
      country = pick(countryNames);
      region = countries[country];
      if (chance(pCategoryOnly)) {
        category = pick(categories);
        basePrice = 20 + rnd.nextDouble() * 300;
      } else {
        product = pick(productNames);
        final (cat, price) = products[product]!;
        category = cat;
        basePrice = price;
      }
    }

    final date = start.add(Duration(days: rnd.nextInt(dayRange)));
    final salesperson = chance(pNoSalesperson) ? null : pick(salespeople);
    final quantity = chance(pNoQuantity) ? null : 1 + rnd.nextInt(20);
    final unitPrice = chance(pNoUnitPrice)
        ? null
        : basePrice * (0.85 + rnd.nextDouble() * 0.3);
    final discount = chance(pNoDiscount) ? null : (rnd.nextInt(7) * 0.05);
    final total = (quantity == null || unitPrice == null)
        ? null
        : quantity * unitPrice * (1 - (discount ?? 0));

    rows.add([
      '$id',
      date.toIso8601String().substring(0, 10),
      region,
      country,
      category,
      product,
      salesperson,
      quantity?.toString(),
      unitPrice == null ? null : money(unitPrice),
      discount?.toStringAsFixed(2),
      total == null ? null : money(total),
    ]);
  }

  String cell(String? v) {
    if (v == null) return '';
    return v.contains(RegExp(r'[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
  }

  final out = StringBuffer()
    ..writeln(
      'id,date,region,country,category,product,salesperson,quantity,unit_price,discount,total',
    );
  for (final row in rows) {
    out.writeln(row.map(cell).join(','));
  }

  for (final file in outPaths.map(File.new)) {
    file.writeAsStringSync(out.toString());
    stdout.writeln('Wrote ${rows.length} rows to ${file.path}');
  }
}
