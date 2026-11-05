import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';
import 'package:xml/xml.dart';

class _SpecialBorder extends Border {}

void main() {
  test(
    'equatable values retain type-specific equality and hash consistency',
    () {
      final first = Border();
      final second = Border();
      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first == _SpecialBorder(), isFalse);
      expect(_SpecialBorder() == first, isFalse);
      expect(
        CellIndex.indexByString('A1'),
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      );
    },
  );

  test('worksheet bounds handle sparse and empty rows without sorting', () {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    sheet.cell(CellIndex.indexByString('Z100')).value = IntCellValue(1);
    sheet.cell(CellIndex.indexByString('A1')).value = IntCellValue(2);
    final decoded = Excel.decodeBytes(excel.encode()!)['Sheet1'];
    expect(decoded.maxRows, 100);
    expect(decoded.maxColumns, 26);
    expect(
      decoded.cell(CellIndex.indexByString('Z100')).value,
      IntCellValue(1),
    );
  });

  test('image detection rejects incomplete PNG and GIF signatures', () {
    expect(
      detectFormat(Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 0, 0, 0, 0])),
      ImageFormat.unknown,
    );
    expect(
      detectFormat(Uint8List.fromList([0x47, 0x49, 0x46, 0, 0, 0])),
      ImageFormat.unknown,
    );
  });

  for (final format in ['png', 'jpg', 'gif']) {
    test('detects and round-trips $format images using image codecs', () async {
      final image = img.Image(width: 3, height: 2);
      final bytes = switch (format) {
        'png' => img.encodePng(image),
        'jpg' => img.encodeJpg(image),
        _ => img.encodeGif(image),
      };
      final value = await ImageCellValue.fromBytes(bytes);
      expect(value.width, 3);
      expect(value.height, 2);
      final excel = Excel.createExcel();
      excel['Sheet1'].cell(CellIndex.indexByString('B2')).value = value;
      final decoded = Excel.decodeBytes(excel.encode()!, verify: true);
      final saved =
          decoded['Sheet1'].cell(CellIndex.indexByString('B2')).value
              as ImageCellValue;
      expect(saved.bytes, bytes);
      expect(saved.format, format);
    });
  }

  for (final absolute in [false, true]) {
    test(
      'resolves ${absolute ? 'absolute' : 'relative'} drawing and image targets',
      () async {
        final excel = Excel.createExcel();
        final bytes = img.encodePng(img.Image(width: 3, height: 2));
        excel['Sheet1'].cell(CellIndex.indexByString('B2')).value =
            await ImageCellValue.fromBytes(bytes);
        final archive = ZipDecoder().decodeBytes(excel.encode()!);
        for (final file in archive.files.toList()) {
          if (!file.name.endsWith('.rels')) {
            continue;
          }
          final doc = XmlDocument.parse(utf8.decode(file.content));
          var changed = false;
          for (final relation in doc.findAllElements('Relationship')) {
            final type = relation.getAttribute('Type') ?? '';
            if (type.endsWith('/drawing')) {
              relation.setAttribute(
                'Target',
                absolute
                    ? '/xl/drawings/./drawing1.xml'
                    : '../drawings/../drawings/drawing1.xml',
              );
              changed = true;
            } else if (type.endsWith('/image')) {
              relation.setAttribute(
                'Target',
                absolute
                    ? '/xl/media/../media/image1.png'
                    : '../media/./image1.png',
              );
              changed = true;
            }
          }
          if (changed) {
            archive.addFile(ArchiveFile.string(file.name, doc.toXmlString()));
          }
        }
        final decoded = Excel.decodeBytes(ZipEncoder().encodeBytes(archive));
        expect(
          (decoded['Sheet1'].cell(CellIndex.indexByString('B2')).value
                  as ImageCellValue)
              .bytes,
          bytes,
        );
        final saved = decoded.encode()!;
        expect(
          ZipDecoder()
              .decodeBytes(saved)
              .files
              .where(
                (f) =>
                    RegExp(r'^xl/drawings/drawing\d+\.xml$').hasMatch(f.name),
              ),
          hasLength(1),
        );
        expect(
          (Excel.decodeBytes(
                    saved,
                  )['Sheet1'].cell(CellIndex.indexByString('B2')).value
                  as ImageCellValue)
              .bytes,
          bytes,
        );
      },
    );
  }

  test('preserves worksheet format extension attributes and namespaces', () {
    final archive = ZipDecoder().decodeBytes(Excel.createExcel().encode()!);
    const path = 'xl/worksheets/sheet1.xml';
    final doc = XmlDocument.parse(utf8.decode(archive.findFile(path)!.content));
    final format = doc.findAllElements('sheetFormatPr').first;
    format.setAttribute('baseColWidth', '10');
    format.attributes.add(
      XmlAttribute(XmlName.namespace(name: 'custom'), 'urn:custom'),
    );
    format.attributes.add(
      XmlAttribute(
        XmlName.parts('flag', prefix: 'custom', namespaceUri: 'urn:custom'),
        'keep',
      ),
    );
    archive.addFile(ArchiveFile.string(path, doc.toXmlString()));
    final excel = Excel.decodeBytes(ZipEncoder().encodeBytes(archive));
    excel['Sheet1'].setDefaultRowHeight(25);
    final saved = ZipDecoder().decodeBytes(excel.encode()!, verify: true);
    final savedFormat = XmlDocument.parse(
      utf8.decode(saved.findFile(path)!.content),
    ).findAllElements('sheetFormatPr').first;
    expect(savedFormat.getAttribute('baseColWidth'), '10');
    expect(
      savedFormat.getAttribute('flag', namespaceUri: 'urn:custom'),
      'keep',
    );
    expect(savedFormat.getAttribute('defaultRowHeight'), '25.00');
  });

  test('checksum verification is available through both decoding APIs', () {
    final bytes = Excel.createExcel().encode()!;
    final name = utf8.encode('[Content_Types].xml');
    var changed = false;
    for (var i = 0; i + 46 + name.length <= bytes.length; i++) {
      if (bytes[i] == 0x50 &&
          bytes[i + 1] == 0x4b &&
          bytes[i + 2] == 1 &&
          bytes[i + 3] == 2 &&
          utf8.decode(
                bytes.sublist(i + 46, i + 46 + name.length),
                allowMalformed: true,
              ) ==
              '[Content_Types].xml') {
        bytes[i + 16] ^= 1;
        changed = true;
        break;
      }
    }
    expect(changed, isTrue);
    expect(
      () => Excel.decodeBytes(bytes, verify: true),
      throwsA(isA<ArchiveException>()),
    );
    expect(
      () => Excel.decodeBuffer(InputMemoryStream(bytes), verify: true),
      throwsA(isA<ArchiveException>()),
    );
  });
}
