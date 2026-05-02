part of excel;

/// Base class for Excel charts written into XLSX drawing parts.
abstract class Chart {
  final String title;
  final List<ChartSeries> series;
  final ChartAnchor anchor;
  final bool showLegend;

  const Chart({
    required this.title,
    required this.series,
    required this.anchor,
    this.showLegend = true,
  });

  String get chartTagName;
}

/// Represents a single data series in a chart.
class ChartSeries {
  final String name;
  final String categoriesRange;
  final String valuesRange;

  /// Optional cached data used when writing chart XML.
  List<String>? categories;

  /// Optional cached data used when writing chart XML.
  List<num>? values;

  ChartSeries({
    required this.name,
    required this.categoriesRange,
    required this.valuesRange,
    this.categories,
    this.values,
  });
}

/// Defines the position and size of a chart on the worksheet.
class ChartAnchor {
  final int fromColumn;
  final int fromRow;
  final int toColumn;
  final int toRow;

  const ChartAnchor({
    required this.fromColumn,
    required this.fromRow,
    required this.toColumn,
    required this.toRow,
  });

  factory ChartAnchor.at({
    required int column,
    required int row,
    int width = 8,
    int height = 15,
  }) {
    return ChartAnchor(
      fromColumn: column,
      fromRow: row,
      toColumn: column + width,
      toRow: row + height,
    );
  }
}
