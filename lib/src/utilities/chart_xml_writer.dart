part of excel;

class ChartXmlWriter {
  XmlDocument generateDrawingXml(List<Chart> charts) {
    final builder = XmlBuilder();
    builder.processing(
      'xml',
      'version="1.0" encoding="UTF-8" standalone="yes"',
    );
    builder.element(
      'xdr:wsDr',
      namespaces: {
        'http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing':
            'xdr',
        'http://schemas.openxmlformats.org/drawingml/2006/main': 'a',
        _relationships: 'r',
      },
      nest: () {
        for (var i = 0; i < charts.length; i++) {
          _buildAnchor(builder, charts[i], i);
        }
      },
    );
    return builder.buildDocument();
  }

  XmlDocument generateChartXml(Chart chart) {
    final builder = XmlBuilder();
    builder.processing(
      'xml',
      'version="1.0" encoding="UTF-8" standalone="yes"',
    );
    builder.element(
      'c:chartSpace',
      namespaces: {
        'http://schemas.openxmlformats.org/drawingml/2006/chart': 'c',
        'http://schemas.openxmlformats.org/drawingml/2006/main': 'a',
        _relationships: 'r',
      },
      nest: () {
        builder.element(
          'c:chart',
          nest: () {
            _buildTitle(builder, chart.title);
            _buildPlotArea(builder, chart);
            if (chart.showLegend) {
              builder.element(
                'c:legend',
                nest: () {
                  builder.element('c:legendPos', attributes: {'val': 'r'});
                  builder.element('c:layout');
                  builder.element('c:overlay', attributes: {'val': '0'});
                },
              );
            }
            builder.element('c:plotVisOnly', attributes: {'val': '1'});
            builder.element('c:dispBlanksAs', attributes: {'val': 'gap'});
            builder.element('c:showDLblsOverMax', attributes: {'val': '0'});
          },
        );
      },
    );
    return builder.buildDocument();
  }

  void _buildAnchor(XmlBuilder builder, Chart chart, int index) {
    builder.element(
      'xdr:twoCellAnchor',
      attributes: {'editAs': 'oneCell'},
      nest: () {
        _buildAnchorPosition(
          builder,
          'xdr:from',
          chart.anchor.fromColumn,
          chart.anchor.fromRow,
        );
        _buildAnchorPosition(
          builder,
          'xdr:to',
          chart.anchor.toColumn,
          chart.anchor.toRow,
        );
        builder.element(
          'xdr:graphicFrame',
          attributes: {'macro': ''},
          nest: () {
            builder.element(
              'xdr:nvGraphicFramePr',
              nest: () {
                builder.element(
                  'xdr:cNvPr',
                  attributes: {
                    'id': '${index + 2}',
                    'name': 'Chart ${index + 1}',
                  },
                );
                builder.element('xdr:cNvGraphicFramePr');
              },
            );
            builder.element(
              'xdr:xfrm',
              nest: () {
                builder.element('a:off', attributes: {'x': '0', 'y': '0'});
                builder.element('a:ext', attributes: {'cx': '0', 'cy': '0'});
              },
            );
            builder.element(
              'a:graphic',
              nest: () {
                builder.element(
                  'a:graphicData',
                  attributes: {
                    'uri':
                        'http://schemas.openxmlformats.org/drawingml/2006/chart',
                  },
                  nest: () {
                    builder.element(
                      'c:chart',
                      namespaces: {
                        'http://schemas.openxmlformats.org/drawingml/2006/chart':
                            'c',
                        _relationships: 'r',
                      },
                      attributes: {'r:id': 'rId${index + 1}'},
                    );
                  },
                );
              },
            );
          },
        );
        builder.element('xdr:clientData');
      },
    );
  }

  void _buildAnchorPosition(
    XmlBuilder builder,
    String element,
    int column,
    int row,
  ) {
    builder.element(
      element,
      nest: () {
        builder.element('xdr:col', nest: () => builder.text('$column'));
        builder.element('xdr:colOff', nest: () => builder.text('0'));
        builder.element('xdr:row', nest: () => builder.text('$row'));
        builder.element('xdr:rowOff', nest: () => builder.text('0'));
      },
    );
  }

  void _buildTitle(XmlBuilder builder, String title) {
    if (title.isEmpty) return;
    builder.element(
      'c:title',
      nest: () {
        builder.element(
          'c:tx',
          nest: () {
            builder.element(
              'c:rich',
              nest: () {
                builder.element('a:bodyPr');
                builder.element('a:lstStyle');
                builder.element(
                  'a:p',
                  nest: () {
                    builder.element(
                      'a:r',
                      nest: () {
                        builder.element('a:rPr', attributes: {'lang': 'en-US'});
                        builder.element('a:t', nest: () => builder.text(title));
                      },
                    );
                  },
                );
              },
            );
          },
        );
        builder.element('c:layout');
        builder.element('c:overlay', attributes: {'val': '0'});
      },
    );
  }

  void _buildPlotArea(XmlBuilder builder, Chart chart) {
    final hasAxes = chart is! PieChart && chart is! DoughnutChart;
    builder.element(
      'c:plotArea',
      nest: () {
        builder.element('c:layout');
        builder.element(
          'c:${chart.chartTagName}',
          nest: () {
            _buildChartProperties(builder, chart);
            for (var i = 0; i < chart.series.length; i++) {
              _buildSeries(builder, chart.series[i], i, chart);
            }
            if (hasAxes) {
              builder.element('c:axId', attributes: {'val': '10000001'});
              builder.element('c:axId', attributes: {'val': '10000002'});
            }
          },
        );
        if (hasAxes) {
          _buildAxes(builder);
        }
      },
    );
  }

  void _buildChartProperties(XmlBuilder builder, Chart chart) {
    switch (chart) {
      case ColumnChart(:final isVertical):
        builder.element(
          'c:barDir',
          attributes: {'val': isVertical ? 'col' : 'bar'},
        );
        builder.element('c:grouping', attributes: {'val': 'clustered'});
      case BarChart():
        builder.element('c:barDir', attributes: {'val': 'bar'});
        builder.element('c:grouping', attributes: {'val': 'clustered'});
      case LineChart():
        builder.element('c:grouping', attributes: {'val': 'standard'});
      case AreaChart():
        builder.element('c:grouping', attributes: {'val': 'standard'});
      case ScatterChart():
        builder.element('c:scatterStyle', attributes: {'val': 'lineMarker'});
      case RadarChart(:final filled):
        builder.element(
          'c:radarStyle',
          attributes: {'val': filled ? 'filled' : 'marker'},
        );
      case DoughnutChart():
        builder.element('c:holeSize', attributes: {'val': '50'});
      case PieChart():
        break;
    }
  }

  void _buildSeries(
    XmlBuilder builder,
    ChartSeries series,
    int index,
    Chart chart,
  ) {
    builder.element(
      'c:ser',
      nest: () {
        builder.element('c:idx', attributes: {'val': '$index'});
        builder.element('c:order', attributes: {'val': '$index'});
        builder.element(
          'c:tx',
          nest: () {
            builder.element('c:v', nest: () => builder.text(series.name));
          },
        );
        if (chart is ScatterChart) {
          _buildRangeRef(
            builder,
            'c:xVal',
            'c:numRef',
            series.categoriesRange,
            numeric: true,
            values: series.categories,
          );
          _buildRangeRef(
            builder,
            'c:yVal',
            'c:numRef',
            series.valuesRange,
            numeric: true,
            nums: series.values,
          );
        } else {
          _buildRangeRef(
            builder,
            'c:cat',
            'c:strRef',
            series.categoriesRange,
            values: series.categories,
          );
          _buildRangeRef(
            builder,
            'c:val',
            'c:numRef',
            series.valuesRange,
            numeric: true,
            nums: series.values,
          );
        }
      },
    );
  }

  void _buildRangeRef(
    XmlBuilder builder,
    String outer,
    String ref,
    String range, {
    bool numeric = false,
    List<String>? values,
    List<num>? nums,
  }) {
    builder.element(
      outer,
      nest: () {
        builder.element(
          ref,
          nest: () {
            builder.element('c:f', nest: () => builder.text(range));
            if (numeric && nums != null) {
              _buildNumCache(builder, nums);
            } else if (values != null) {
              _buildStrCache(builder, values);
            }
          },
        );
      },
    );
  }

  void _buildStrCache(XmlBuilder builder, List<String> values) {
    builder.element(
      'c:strCache',
      nest: () {
        builder.element('c:ptCount', attributes: {'val': '${values.length}'});
        for (var i = 0; i < values.length; i++) {
          builder.element(
            'c:pt',
            attributes: {'idx': '$i'},
            nest: () {
              builder.element('c:v', nest: () => builder.text(values[i]));
            },
          );
        }
      },
    );
  }

  void _buildNumCache(XmlBuilder builder, List<num> values) {
    builder.element(
      'c:numCache',
      nest: () {
        builder.element('c:formatCode', nest: () => builder.text('General'));
        builder.element('c:ptCount', attributes: {'val': '${values.length}'});
        for (var i = 0; i < values.length; i++) {
          builder.element(
            'c:pt',
            attributes: {'idx': '$i'},
            nest: () {
              builder.element('c:v', nest: () => builder.text('${values[i]}'));
            },
          );
        }
      },
    );
  }

  void _buildAxes(XmlBuilder builder) {
    builder.element(
      'c:catAx',
      nest: () {
        builder.element('c:axId', attributes: {'val': '10000001'});
        builder.element(
          'c:scaling',
          nest: () {
            builder.element('c:orientation', attributes: {'val': 'minMax'});
          },
        );
        builder.element('c:delete', attributes: {'val': '0'});
        builder.element('c:axPos', attributes: {'val': 'b'});
        builder.element('c:tickLblPos', attributes: {'val': 'nextTo'});
        builder.element('c:crossAx', attributes: {'val': '10000002'});
        builder.element('c:crosses', attributes: {'val': 'autoZero'});
      },
    );
    builder.element(
      'c:valAx',
      nest: () {
        builder.element('c:axId', attributes: {'val': '10000002'});
        builder.element(
          'c:scaling',
          nest: () {
            builder.element('c:orientation', attributes: {'val': 'minMax'});
          },
        );
        builder.element('c:delete', attributes: {'val': '0'});
        builder.element('c:axPos', attributes: {'val': 'l'});
        builder.element('c:majorGridlines');
        builder.element(
          'c:numFmt',
          attributes: {'formatCode': 'General', 'sourceLinked': '1'},
        );
        builder.element('c:tickLblPos', attributes: {'val': 'nextTo'});
        builder.element('c:crossAx', attributes: {'val': '10000001'});
        builder.element('c:crosses', attributes: {'val': 'autoZero'});
        builder.element('c:crossBetween', attributes: {'val': 'between'});
      },
    );
  }
}
