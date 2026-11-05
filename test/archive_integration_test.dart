import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:test/test.dart';

void main() {
  test('rejects malformed ZIP input through both decode APIs', () {
    final bytes = [1, 2, 3, 4];
    expect(() => Excel.decodeBytes(bytes), throwsUnsupportedError);
    expect(
      () => Excel.decodeBuffer(InputMemoryStream(bytes)),
      throwsA(anything),
    );
  });

  test('preserves untouched ZIP data and metadata across repeated saves', () {
    final source = ZipDecoder().decodeBytes(Excel.createExcel().encode()!);
    source.addFile(ArchiveFile.directory('custom/')..lastModTime = 1700000000);
    final payload = List<int>.generate(20000, (i) => i % 251);
    source.addFile(
      ArchiveFile.bytes('custom/payload.bin', payload)
        ..lastModTime = 1700000000
        ..comment = 'entry comment'
        ..compression = CompressionType.deflate,
    );
    final input = ZipEncoder().encodeBytes(source);
    final original = ZipDecoder()
        .decodeBytes(input)
        .findFile('custom/payload.bin')!;
    expect(
      () => Excel.decodeBytes(input.sublist(0, input.length - 30)),
      throwsUnsupportedError,
    );
    final excel = Excel.decodeBuffer(InputMemoryStream(input));
    excel['Sheet1'].cell(CellIndex.indexByString('A1')).value = TextCellValue(
      '  <tag> & "quotes" 😀\nsecond line  ',
    );

    for (var i = 0; i < 2; i++) {
      final output = OutputMemoryStream();
      excel.encodeToStream(output);
      final bytes = output.getBytes();
      final saved = ZipDecoder().decodeBytes(bytes, verify: true);
      final entry = saved.findFile('custom/payload.bin')!;
      expect(entry.content, payload);
      expect(entry.lastModTime, original.lastModTime);
      expect(entry.comment, original.comment);
      expect(entry.compression, original.compression);
      expect(
        entry.rawContent!.getStream(decompress: false).toUint8List(),
        original.rawContent!.getStream(decompress: false).toUint8List(),
      );
      expect(saved.findFile('custom/')!.isDirectory, isTrue);
      expect(
        Excel.decodeBytes(
          bytes,
        )['Sheet1'].cell(CellIndex.indexByString('A1')).value,
        TextCellValue('  <tag> & "quotes" 😀\nsecond line  '),
      );
    }
    expect(Excel.decodeBytes(excel.encode()!).sheets, isNotEmpty);
  });
}
