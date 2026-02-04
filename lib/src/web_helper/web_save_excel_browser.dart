import 'dart:typed_data';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

class SavingHelper {
  static List<int>? saveFile(List<int>? val, String fileName) {
    if (val == null) return null;

    // Dart bytes
    final bytes = Uint8List.fromList(val);

    // Uint8List → JSUint8Array (valid BlobPart)
    final jsBytes = bytes.toJS;

    // JSArray<BlobPart>
    final parts = <web.BlobPart>[jsBytes].toJS;

    final blob = web.Blob(
      parts,
      web.BlobPropertyBag(type: 'application/octet-stream'),
    );

    final url = web.URL.createObjectURL(blob);

    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = fileName
      ..style.display = 'none';

    web.document.body?.append(anchor);
    anchor.click();

    anchor.remove();
    web.URL.revokeObjectURL(url);

    return val;
  }
}
