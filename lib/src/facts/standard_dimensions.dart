import '../schema/column_type.dart';
import 'dimension.dart';
import 'fact_table.dart';

/// The dimensions a UI can offer for [facts] without further configuration:
/// a [ColumnDimension] for every column, and for date/dateTime columns the
/// calendar parts ([DatePart.year], [DatePart.quarter], [DatePart.month],
/// [DatePart.week], [DatePart.day], [DatePart.weekday]; [DatePart.hour] for
/// dateTime only).
///
/// Order follows the columns; parts follow their column, coarse to fine.
/// No explicit labels are set, so the widgets show the column labels of
/// the fact table and localized date-part names.
List<Dimension> standardDimensions(FactTable facts) => [
  for (final column in facts.columns) ...[
    ColumnDimension(column.name),
    if (column.type == ColumnType.date || column.type == ColumnType.dateTime)
      for (final part in DatePart.values)
        if (part != DatePart.hour || column.type == ColumnType.dateTime)
          DatePartDimension(column.name, part),
  ],
];
