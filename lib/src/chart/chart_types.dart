part of excel;

class ColumnChart extends Chart {
  final bool isVertical;

  const ColumnChart({
    required super.title,
    required super.series,
    required super.anchor,
    super.showLegend,
    this.isVertical = true,
  });

  @override
  String get chartTagName => 'barChart';
}

class BarChart extends Chart {
  const BarChart({
    required super.title,
    required super.series,
    required super.anchor,
    super.showLegend,
  });

  @override
  String get chartTagName => 'barChart';
}

class LineChart extends Chart {
  const LineChart({
    required super.title,
    required super.series,
    required super.anchor,
    super.showLegend,
  });

  @override
  String get chartTagName => 'lineChart';
}

class PieChart extends Chart {
  const PieChart({
    required super.title,
    required super.series,
    required super.anchor,
    super.showLegend,
  });

  @override
  String get chartTagName => 'pieChart';
}

class DoughnutChart extends Chart {
  const DoughnutChart({
    required super.title,
    required super.series,
    required super.anchor,
    super.showLegend,
  });

  @override
  String get chartTagName => 'doughnutChart';
}

class AreaChart extends Chart {
  const AreaChart({
    required super.title,
    required super.series,
    required super.anchor,
    super.showLegend,
  });

  @override
  String get chartTagName => 'areaChart';
}

class ScatterChart extends Chart {
  const ScatterChart({
    required super.title,
    required super.series,
    required super.anchor,
    super.showLegend,
  });

  @override
  String get chartTagName => 'scatterChart';
}

class RadarChart extends Chart {
  final bool filled;

  const RadarChart({
    required super.title,
    required super.series,
    required super.anchor,
    super.showLegend,
    this.filled = false,
  });

  @override
  String get chartTagName => 'radarChart';
}
