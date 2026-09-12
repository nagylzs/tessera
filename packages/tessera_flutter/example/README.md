# tessera_example

Demo app for `tessera` / `tessera_flutter`. `lib/main.dart` is a launcher
listing the examples in `lib/examples.dart`:

* **Simple pivot** (`lib/simple/`) — `assets/sales.csv` with editable
  schema, axes, aggregates and language.
* **Public datasets** (`lib/datasets/`) — real CSV files downloaded through
  a custom `HttpCsvDataSource` (`lib/common/http_csv_data_source.dart`).

```bash
flutter run
dart run tool/gen_sales_csv.dart   # regenerate assets/sales.csv (seeded)
dart run tool/bench.dart           # import/cube timings on a big file
```
