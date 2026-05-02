part of excel;

class _ChartManager {
  final Excel _excel;

  _ChartManager(this._excel);

  void processCharts() {
    final writer = ChartXmlWriter();
    var chartCount = _nextPartNumber(r'^xl/charts/chart(\d+)\.xml$');
    var drawingCount = _nextPartNumber(r'^xl/drawings/drawing(\d+)\.xml$');

    _excel._sheetMap.forEach((sheetName, sheet) {
      if (sheet._charts.isEmpty) return;

      final drawingNumber = drawingCount++;
      final drawingPath = 'xl/drawings/drawing$drawingNumber.xml';
      final drawingRelsPath =
          'xl/drawings/_rels/drawing$drawingNumber.xml.rels';
      final sheetPath = _excel._xmlSheetId[sheetName];
      if (sheetPath == null) return;

      final drawingRelsBuilder = XmlBuilder();
      drawingRelsBuilder.processing(
        'xml',
        'version="1.0" encoding="UTF-8" standalone="yes"',
      );
      drawingRelsBuilder.element(
        'Relationships',
        namespaces: {
          'http://schemas.openxmlformats.org/package/2006/relationships': '',
        },
        nest: () {
          for (var i = 0; i < sheet._charts.length; i++) {
            final chartNumber = chartCount++;
            final chart = sheet._charts[i];
            _hydrateSeries(chart);

            _excel._xmlFiles['xl/charts/chart$chartNumber.xml'] = writer
                .generateChartXml(chart);
            _addOverrideContentType(
              '/xl/charts/chart$chartNumber.xml',
              'application/vnd.openxmlformats-officedocument.drawingml.chart+xml',
            );
            drawingRelsBuilder.element(
              'Relationship',
              attributes: {
                'Id': 'rId${i + 1}',
                'Type':
                    'http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart',
                'Target': '../charts/chart$chartNumber.xml',
              },
            );
          }
        },
      );

      _excel._xmlFiles[drawingRelsPath] = drawingRelsBuilder.buildDocument();
      _excel._xmlFiles[drawingPath] = writer.generateDrawingXml(sheet._charts);
      _addOverrideContentType(
        '/$drawingPath',
        'application/vnd.openxmlformats-officedocument.drawing+xml',
      );

      final drawingRId = _addSheetDrawingRelationship(sheetPath, drawingNumber);
      _addWorksheetDrawing(sheetPath, drawingRId);
    });
  }

  void _hydrateSeries(Chart chart) {
    for (final series in chart.series) {
      series.categories ??= _resolveChartRange(
        series.categoriesRange,
      ).map((value) => value?.toString() ?? '').toList(growable: false);
      series.values ??= _resolveChartRange(
        series.valuesRange,
      ).map(_toNumericChartValue).toList(growable: false);
    }
  }

  num _toNumericChartValue(CellValue? value) {
    return switch (value) {
      IntCellValue(:final value) => value,
      DoubleCellValue(:final value) => value,
      TextCellValue() => num.tryParse(value.toString()) ?? 0,
      BoolCellValue(:final value) => value ? 1 : 0,
      _ => 0,
    };
  }

  List<CellValue?> _resolveChartRange(String range) {
    final parts = range.split('!');
    if (parts.length != 2) return const [];

    final sheetName = parts[0].replaceAll("'", '');
    final cellRange = parts[1].replaceAll(r'$', '');
    final sheet = _excel._sheetMap[sheetName];
    if (sheet == null) return const [];

    final rangeParts = cellRange.split(':');
    final start = _cellCoordsFromCellId(rangeParts.first);
    final end = rangeParts.length == 1
        ? start
        : _cellCoordsFromCellId(rangeParts[1]);

    final values = <CellValue?>[];
    for (var row = start.$1; row <= end.$1; row++) {
      for (var column = start.$2; column <= end.$2; column++) {
        values.add(sheet._sheetData[row]?[column]?.value);
      }
    }
    return values;
  }

  String _addSheetDrawingRelationship(String sheetPath, int drawingNumber) {
    final relsPath = 'xl/worksheets/_rels/${basename(sheetPath)}.rels';
    final relsDoc = _excel._xmlFiles.putIfAbsent(relsPath, () {
      final builder = XmlBuilder();
      builder.processing(
        'xml',
        'version="1.0" encoding="UTF-8" standalone="yes"',
      );
      builder.element(
        'Relationships',
        namespaces: {
          'http://schemas.openxmlformats.org/package/2006/relationships': '',
        },
      );
      return builder.buildDocument();
    });

    final root = relsDoc.rootElement;
    final target = '../drawings/drawing$drawingNumber.xml';
    final existing = root
        .findElements('Relationship')
        .firstWhereOrNull(
          (element) =>
              element.getAttribute('Type') == _relationshipsDrawing &&
              element.getAttribute('Target') == target,
        );
    if (existing != null) {
      return existing.getAttribute('Id')!;
    }

    final ids = root
        .findElements('Relationship')
        .map((element) => element.getAttribute('Id'))
        .whereType<String>()
        .where((id) => id.startsWith('rId'))
        .map((id) => int.tryParse(id.substring(3)))
        .whereType<int>()
        .toList();
    final nextRid = ids.isEmpty ? 1 : ids.reduce(max) + 1;
    final rId = 'rId$nextRid';
    root.children.add(
      XmlElement(XmlName('Relationship'), [
        XmlAttribute(XmlName('Id'), rId),
        XmlAttribute(XmlName('Type'), _relationshipsDrawing),
        XmlAttribute(XmlName('Target'), target),
      ]),
    );
    return rId;
  }

  void _addWorksheetDrawing(String sheetPath, String drawingRId) {
    final worksheet = _excel._xmlFiles[sheetPath]?.rootElement;
    if (worksheet == null) return;
    if (worksheet.findElements('drawing').isNotEmpty) return;

    final drawing = XmlElement(XmlName('drawing'), [
      XmlAttribute(XmlName('id', 'r'), drawingRId),
    ]);
    final tagsAfterDrawing = {
      'legacyDrawing',
      'picture',
      'oleObjects',
      'drawingHF',
      'extLst',
    };
    final insertIndex = worksheet.children.indexWhere(
      (node) =>
          node is XmlElement && tagsAfterDrawing.contains(node.name.local),
    );
    if (insertIndex == -1) {
      worksheet.children.add(drawing);
    } else {
      worksheet.children.insert(insertIndex, drawing);
    }
  }

  void _addOverrideContentType(String partName, String contentType) {
    final root = _excel._xmlFiles['[Content_Types].xml']?.rootElement;
    if (root == null) return;
    final exists = root
        .findElements('Override')
        .any((element) => element.getAttribute('PartName') == partName);
    if (exists) return;
    root.children.add(
      XmlElement(XmlName('Override'), [
        XmlAttribute(XmlName('PartName'), partName),
        XmlAttribute(XmlName('ContentType'), contentType),
      ]),
    );
  }

  int _nextPartNumber(String pattern) {
    final expression = RegExp(pattern);
    final numbers =
        {
              ..._excel._archive.files.map((file) => file.name),
              ..._excel._xmlFiles.keys,
            }
            .map(expression.firstMatch)
            .whereType<RegExpMatch>()
            .map((match) => int.tryParse(match.group(1)!))
            .whereType<int>()
            .toList();
    return numbers.isEmpty ? 1 : numbers.reduce(max) + 1;
  }
}
