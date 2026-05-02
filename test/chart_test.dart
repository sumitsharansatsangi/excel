import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:test/test.dart';

void main() {
  test('saves charts with drawing relationships and cached data', () {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    sheet.appendRow([TextCellValue('Month'), TextCellValue('Sales')]);
    sheet.appendRow([TextCellValue('Jan'), IntCellValue(10)]);
    sheet.appendRow([TextCellValue('Feb'), IntCellValue(20)]);

    sheet.addChart(
      ColumnChart(
        title: 'Sales',
        anchor: ChartAnchor.at(column: 3, row: 1),
        series: [
          ChartSeries(
            name: 'Sales',
            categoriesRange: r'Sheet1!$A$2:$A$3',
            valuesRange: r'Sheet1!$B$2:$B$3',
          ),
        ],
      ),
    );

    final bytes = excel.save()!;
    final archive = ZipDecoder().decodeBytes(bytes);

    String read(String path) {
      final file = archive.findFile(path);
      expect(file, isNotNull, reason: '$path should exist');
      file!.decompress();
      return utf8.decode(file.content as List<int>);
    }

    final worksheet = read('xl/worksheets/sheet1.xml');
    final worksheetRels = read('xl/worksheets/_rels/sheet1.xml.rels');
    final drawing = read('xl/drawings/drawing2.xml');
    final drawingRels = read('xl/drawings/_rels/drawing2.xml.rels');
    final chart = read('xl/charts/chart1.xml');
    final contentTypes = read('[Content_Types].xml');

    expect(worksheet, contains('<drawing r:id="'));
    expect(worksheetRels, contains('../drawings/drawing2.xml'));
    expect(drawing, contains('r:id="rId1"'));
    expect(drawingRels, contains('../charts/chart1.xml'));
    expect(chart, contains('<c:barChart>'));
    expect(chart, contains('<c:f>Sheet1!\$A\$2:\$A\$3</c:f>'));
    expect(chart, contains('<c:v>Jan</c:v>'));
    expect(chart, contains('<c:v>20</c:v>'));
    expect(contentTypes, contains('/xl/charts/chart1.xml'));
    expect(contentTypes, contains('/xl/drawings/drawing2.xml'));
  });
}
