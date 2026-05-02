part of excel;

class _ImageCellCreator {
  final Map<String, ArchiveFile> _archiveFiles;
  final Excel _excel;

  _ImageCellCreator(this._excel, this._archiveFiles);

  /// The number of EMUs (English Metric Units) per pixel.
  static const int _emusPerPixel = 9525;

  XmlElement createImageCell(
    String sheet,
    int columnIndex,
    int rowIndex,
    ImageCellValue image,
  ) {
    _validateInputs(columnIndex, rowIndex, image);

    final worksheetPath = _excel._xmlSheetId[sheet]!;
    final worksheet = _excel._xmlFiles[worksheetPath]!;
    final sheetName = worksheetPath.split('/').last;
    final sheetRelsPath = 'xl/worksheets/_rels/$sheetName.rels';

    final drawingInfo = _setupDrawing(worksheet, sheetRelsPath);
    final drawingPath = 'xl/drawings/drawing${drawingInfo.drawingNumber}.xml';
    final drawingRelsPath =
        'xl/drawings/_rels/drawing${drawingInfo.drawingNumber}.xml.rels';
    final imageRId = _getAvailableRid(drawingRelsPath);
    final imageFileName = _getAvailableImageFileName(image);

    _addImageFile(image, imageFileName);
    _updateDrawingXml(
      drawingPath,
      columnIndex,
      rowIndex,
      image,
      imageRId,
      imageFileName,
    );
    _updateRelationships(
      sheetRelsPath,
      drawingRelsPath,
      drawingInfo.drawingNumber,
      drawingInfo.drawingRId,
      imageRId,
      image,
      imageFileName,
    );
    _updateContentTypes(drawingInfo.drawingNumber, imageFileName);

    return _createCellElement(columnIndex, rowIndex);
  }

  void _validateInputs(int columnIndex, int rowIndex, ImageCellValue image) {
    if (columnIndex < 0 || rowIndex < 0) {
      throw ArgumentError('Column and row indices must be non-negative');
    }

    if (image.bytes.isEmpty) {
      throw ArgumentError('Image bytes cannot be empty');
    }

    final bytes = image.bytes;

    bool isPng =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;

    bool isJpeg = bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;

    bool isGif =
        bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46;

    if (!(isPng || isJpeg || isGif)) {
      throw ArgumentError(
        'Unsupported or invalid image format. Supported formats: PNG, JPEG, GIF',
      );
    }
  }

  ({XmlElement? existingDrawing, String drawingRId, int drawingNumber})
  _setupDrawing(XmlDocument worksheet, String sheetRelsPath) {
    final existingDrawing = worksheet.findAllElements('drawing').firstOrNull;
    if (existingDrawing != null) {
      final drawingRId = existingDrawing.getAttribute('r:id');
      final drawingTarget = drawingRId == null
          ? null
          : _relationshipTarget(sheetRelsPath, drawingRId);
      final drawingNumber =
          _drawingNumberFromTarget(drawingTarget) ??
          int.tryParse(drawingRId?.replaceAll(RegExp(r'\D'), '') ?? '');

      if (drawingRId != null && drawingNumber != null) {
        return (
          existingDrawing: existingDrawing,
          drawingRId: drawingRId,
          drawingNumber: drawingNumber,
        );
      }
    }

    final drawingRId = 'rId${_getAvailableRid(sheetRelsPath)}';
    final drawingNumber = _getNextDrawingNumber();
    _addWorksheetDrawingElement(worksheet, drawingRId);

    return (
      existingDrawing: existingDrawing,
      drawingRId: drawingRId,
      drawingNumber: drawingNumber,
    );
  }

  void _addWorksheetDrawingElement(XmlDocument worksheet, String drawingRId) {
    final drawingElement = XmlElement(XmlName('drawing'), [
      XmlAttribute(XmlName('r:id'), drawingRId),
    ]);
    final sheetData = worksheet.findAllElements('sheetData').firstOrNull;
    final worksheetElement = worksheet.rootElement;
    final index = sheetData == null
        ? worksheetElement.children.length
        : worksheetElement.children.indexOf(sheetData) + 1;
    worksheetElement.children.insert(index, drawingElement);
  }

  void _addImageFile(ImageCellValue image, String imageFileName) {
    if (image.bytes.isEmpty) {
      throw ArgumentError('Image bytes cannot be empty');
    }

    final imagePath = 'xl/media/$imageFileName';

    _archiveFiles[imagePath] = ArchiveFile(
      imagePath,
      image.bytes.length,
      image.bytes,
    );
  }

  void _updateDrawingXml(
    String drawingPath,
    int columnIndex,
    int rowIndex,
    ImageCellValue image,
    int rId,
    String imageFileName,
  ) {
    final int widthEmu = image.width * _emusPerPixel;
    final int heightEmu = image.height * _emusPerPixel;

    String drawing;
    final existingDrawing = _readArchiveText(drawingPath);
    if (existingDrawing != null) {
      drawing = _updateExistingDrawing(
        existingDrawing,
        columnIndex,
        rowIndex,
        widthEmu,
        heightEmu,
        rId,
        imageFileName,
      );
    } else {
      drawing = _createNewDrawing(
        columnIndex,
        rowIndex,
        widthEmu,
        heightEmu,
        rId,
        imageFileName,
      );
    }

    _archiveFiles[drawingPath] = ArchiveFile(
      drawingPath,
      drawing.length,
      utf8.encode(drawing),
    );
  }

  String _updateExistingDrawing(
    String existingDrawing,
    int columnIndex,
    int rowIndex,
    int width,
    int height,
    int rId,
    String imageFileName,
  ) {
    var xmlDoc = XmlDocument.parse(existingDrawing);
    var wsDrElement = xmlDoc.findAllElements('xdr:wsDr').first;

    var anchorElement = _createAnchorElement(
      columnIndex,
      rowIndex,
      width,
      height,
      rId,
      imageFileName,
    );
    wsDrElement.children.add(
      XmlDocument.parse(anchorElement).rootElement.copy(),
    );

    return xmlDoc.toXmlString();
  }

  String _createNewDrawing(
    int columnIndex,
    int rowIndex,
    int width,
    int height,
    int rId,
    String imageFileName,
  ) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing"
          xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
          xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  ${_createAnchorElement(columnIndex, rowIndex, width, height, rId, imageFileName)}
</xdr:wsDr>''';
  }

  String _createAnchorElement(
    int columnIndex,
    int rowIndex,
    int width,
    int height,
    int rId,
    String imageFileName,
  ) {
    return '''<xdr:oneCellAnchor editAs="twoCell">
  <xdr:from>
    <xdr:col>$columnIndex</xdr:col>
    <xdr:colOff>0</xdr:colOff>
    <xdr:row>$rowIndex</xdr:row>
    <xdr:rowOff>0</xdr:rowOff>
  </xdr:from>
  <xdr:ext cx="$width" cy="$height"/>
  <xdr:pic>
    <xdr:nvPicPr>
      <xdr:cNvPr id="$rId" name="$imageFileName"/>
      <xdr:cNvPicPr preferRelativeResize="0"/>
    </xdr:nvPicPr>
    <xdr:blipFill>
      <a:blip cstate="print" r:embed="rId$rId"/>
      <a:stretch>
        <a:fillRect/>
      </a:stretch>
    </xdr:blipFill>
    <xdr:spPr>
      <a:prstGeom prst="rect">
        <a:avLst/>
      </a:prstGeom>
      <a:noFill/>
    </xdr:spPr>
  </xdr:pic>
  <xdr:clientData fLocksWithSheet="0"/>
</xdr:oneCellAnchor>''';
  }

  void _updateRelationships(
    String sheetRelsPath,
    String drawingRelsPath,
    int drawingNumber,
    String drawingRId,
    int imageRId,
    ImageCellValue image,
    String imageFileName,
  ) {
    _updateSheetRelationships(sheetRelsPath, drawingNumber, drawingRId);
    _updateDrawingRelationships(
      drawingRelsPath,
      imageRId,
      image,
      imageFileName,
    );
  }

  void _updateSheetRelationships(
    String sheetRelsPath,
    int drawingNumber,
    String drawingRId,
  ) {
    String sheetRels;
    var content = _readArchiveText(sheetRelsPath) ?? '';
    XmlDocument relsDoc;

    if (content.isEmpty) {
      relsDoc = _createNewRelationshipsDoc();
    } else {
      relsDoc = _ensureRelationshipsRoot(content);
    }

    var relsRoot = relsDoc.rootElement;
    _addDrawingRelationship(relsRoot, drawingNumber, drawingRId);

    sheetRels = relsDoc.toXmlString();
    _archiveFiles[sheetRelsPath] = ArchiveFile(
      sheetRelsPath,
      sheetRels.length,
      utf8.encode(sheetRels),
    );
  }

  XmlDocument _createNewRelationshipsDoc() {
    return XmlDocument([
      XmlDeclaration([
        XmlAttribute(XmlName('version'), '1.0'),
        XmlAttribute(XmlName('encoding'), 'UTF-8'),
        XmlAttribute(XmlName('standalone'), 'yes'),
      ]),
      XmlElement(XmlName('Relationships'), [
        XmlAttribute(
          XmlName('xmlns'),
          'http://schemas.openxmlformats.org/package/2006/relationships',
        ),
      ], []),
    ]);
  }

  XmlDocument _ensureRelationshipsRoot(String content) {
    var doc = XmlDocument.parse(content);
    if (!doc.rootElement.name.local.contains('Relationships')) {
      return XmlDocument([
        XmlElement(XmlName('Relationships'), [
          XmlAttribute(
            XmlName('xmlns'),
            'http://schemas.openxmlformats.org/package/2006/relationships',
          ),
        ], doc.rootElement.children),
      ]);
    }
    return doc;
  }

  void _addDrawingRelationship(
    XmlElement relsRoot,
    int drawingNumber,
    String drawingRId,
  ) {
    if (relsRoot
        .findElements("Relationship")
        .none((element) => element.getAttribute("Id") == drawingRId)) {
      var newRel = XmlElement(XmlName('Relationship'), [
        XmlAttribute(XmlName('Id'), drawingRId),
        XmlAttribute(
          XmlName('Type'),
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing',
        ),
        XmlAttribute(
          XmlName('Target'),
          '../drawings/drawing$drawingNumber.xml',
        ),
      ]);
      relsRoot.children.add(newRel);
    }
  }

  void _updateDrawingRelationships(
    String drawingRelsPath,
    int rId,
    ImageCellValue image,
    String imageFileName,
  ) {
    String drawingRels;
    final existingDrawingRels = _readArchiveText(drawingRelsPath);
    if (existingDrawingRels != null) {
      drawingRels = _updateExistingDrawingRels(
        existingDrawingRels,
        rId,
        imageFileName,
      );
    } else {
      drawingRels = _createNewDrawingRels(rId, imageFileName);
    }
    _archiveFiles[drawingRelsPath] = ArchiveFile(
      drawingRelsPath,
      drawingRels.length,
      utf8.encode(drawingRels),
    );
  }

  String _detectImageExtension(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }

    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'jpg';
    }

    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return 'gif';
    }

    throw ArgumentError('Unsupported image format');
  }

  String _updateExistingDrawingRels(
    String existingRels,
    int rId,
    String imageFileName,
  ) {
    final relsDoc = XmlDocument.parse(existingRels);

    final relationships = relsDoc.findAllElements('Relationships').first;

    relationships.children.add(
      XmlElement(XmlName('Relationship'), [
        XmlAttribute(XmlName('Id'), 'rId$rId'),
        XmlAttribute(
          XmlName('Type'),
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image',
        ),
        XmlAttribute(XmlName('Target'), '../media/$imageFileName'),
      ]),
    );

    return relsDoc.toXmlString();
  }

  String _createNewDrawingRels(int rId, String imageFileName) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship 
    Id="rId$rId" 
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" 
    Target="../media/$imageFileName"/>
</Relationships>''';
  }

  XmlElement _createCellElement(int columnIndex, int rowIndex) {
    return XmlElement(XmlName('c'), [
      XmlAttribute(XmlName('r'), getCellId(columnIndex, rowIndex)),
    ], []);
  }

  void _updateContentTypes(int drawingNumber, String imageFileName) {
    final contentTypes = _excel._xmlFiles['[Content_Types].xml'];
    if (contentTypes == null) {
      return;
    }

    final root = contentTypes.rootElement;
    final imageExtension = extension(
      imageFileName,
    ).replaceFirst('.', '').toLowerCase();
    final imageContentType = switch (imageExtension) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      _ => null,
    };

    if (imageContentType != null) {
      _addDefaultContentType(root, imageExtension, imageContentType);
    }

    _addOverrideContentType(
      root,
      '/xl/drawings/drawing$drawingNumber.xml',
      'application/vnd.openxmlformats-officedocument.drawing+xml',
    );
  }

  void _addDefaultContentType(
    XmlElement root,
    String extension,
    String contentType,
  ) {
    final exists = root
        .findElements('Default')
        .any((element) => element.getAttribute('Extension') == extension);
    if (exists) {
      return;
    }

    root.children.add(
      XmlElement(XmlName('Default'), [
        XmlAttribute(XmlName('Extension'), extension),
        XmlAttribute(XmlName('ContentType'), contentType),
      ]),
    );
  }

  void _addOverrideContentType(
    XmlElement root,
    String partName,
    String contentType,
  ) {
    final exists = root
        .findElements('Override')
        .any((element) => element.getAttribute('PartName') == partName);
    if (exists) {
      return;
    }

    root.children.add(
      XmlElement(XmlName('Override'), [
        XmlAttribute(XmlName('PartName'), partName),
        XmlAttribute(XmlName('ContentType'), contentType),
      ]),
    );
  }

  int _getAvailableRid(String sheetRelsPath) {
    final content = _readArchiveText(sheetRelsPath);
    if (content == null || content.isEmpty) {
      return 1;
    }

    final doc = XmlDocument.parse(content);
    final allRids = doc
        .findAllElements('Relationship')
        .map((e) => e.getAttribute('Id'))
        .whereType<String>()
        .where((id) => id.startsWith('rId'))
        .map((id) => int.tryParse(id.substring(3)))
        .whereType<int>()
        .toList();

    return allRids.isEmpty ? 1 : (allRids.reduce(max) + 1);
  }

  String _getAvailableImageFileName(ImageCellValue image) {
    final extension = _detectImageExtension(image.bytes);
    return 'image${_getNextMediaNumber()}.$extension';
  }

  int _getNextDrawingNumber() {
    final numbers = _allArchivePaths()
        .map(
          (path) => RegExp(r'^xl/drawings/drawing(\d+)\.xml$').firstMatch(path),
        )
        .whereType<RegExpMatch>()
        .map((match) => int.tryParse(match.group(1)!))
        .whereType<int>()
        .toList();

    return numbers.isEmpty ? 1 : numbers.reduce(max) + 1;
  }

  int _getNextMediaNumber() {
    final numbers = _allArchivePaths()
        .map((path) => RegExp(r'^xl/media/image(\d+)\.[^.]+$').firstMatch(path))
        .whereType<RegExpMatch>()
        .map((match) => int.tryParse(match.group(1)!))
        .whereType<int>()
        .toList();

    return numbers.isEmpty ? 1 : numbers.reduce(max) + 1;
  }

  int? _drawingNumberFromTarget(String? target) {
    if (target == null) {
      return null;
    }

    final match = RegExp(r'drawing(\d+)\.xml$').firstMatch(target);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  String? _relationshipTarget(String relsPath, String id) {
    final content = _readArchiveText(relsPath);
    if (content == null || content.isEmpty) {
      return null;
    }

    final relationship = XmlDocument.parse(content)
        .findAllElements('Relationship')
        .firstWhereOrNull((element) => element.getAttribute('Id') == id);
    final target = relationship?.getAttribute('Target');
    if (target == null) {
      return null;
    }

    return target.startsWith('../')
        ? 'xl/${target.substring(3)}'
        : 'xl/worksheets/$target';
  }

  String? _readArchiveText(String path) {
    final archiveFile = _archiveFiles[path] ?? _excel._archive.findFile(path);
    if (archiveFile == null) {
      return null;
    }

    archiveFile.decompress();
    return utf8.decode(archiveFile.content);
  }

  Iterable<String> _allArchivePaths() sync* {
    yield* _excel._archive.files.map((file) => file.name);
    yield* _archiveFiles.keys;
  }
}
