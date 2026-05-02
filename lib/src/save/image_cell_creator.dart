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
    final rId = _getAvailableRid(sheetRelsPath);

    final drawingInfo = _setupDrawing(worksheet, rId);
    final drawingPath = 'xl/drawings/drawing${drawingInfo.drawingNumber}.xml';
    final drawingRelsPath =
        'xl/drawings/_rels/drawing${drawingInfo.drawingNumber}.xml.rels';

    _addImageFile(image, rId);
    _updateDrawingXml(drawingPath, columnIndex, rowIndex, image, rId);
    _updateRelationships(
      sheetRelsPath,
      drawingRelsPath,
      drawingInfo.drawingNumber,
      rId,
      image,
    );

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
  _setupDrawing(XmlDocument worksheet, int rId) {
    final existingDrawing = worksheet.findAllElements('drawing').firstOrNull;
    final drawingRId = existingDrawing?.getAttribute('r:id') ?? 'rId$rId';
    final drawingNumber = existingDrawing != null
        ? int.parse(drawingRId.replaceAll(RegExp(r'\D'), ''))
        : rId;

    return (
      existingDrawing: existingDrawing,
      drawingRId: drawingRId,
      drawingNumber: drawingNumber,
    );
  }

  void _addImageFile(ImageCellValue image, int rId) {
    if (image.bytes.isEmpty) {
      throw ArgumentError('Image bytes cannot be empty');
    }

    final format = detectFormat(image.bytes);

    if (format == ImageFormat.unknown) {
      throw ArgumentError('Unsupported image format');
    }

    final extension = switch (format) {
      ImageFormat.png => 'png',
      ImageFormat.jpeg => 'jpg',
      ImageFormat.gif => 'gif',
      ImageFormat.unknown => throw ArgumentError('Unsupported image format'),
    };

    final imageFileName = 'image$rId.$extension';
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
  ) {
    final int widthEmu = image.width * _emusPerPixel;
    final int heightEmu = image.height * _emusPerPixel;

    String drawing;
    if (_archiveFiles.containsKey(drawingPath)) {
      drawing = _updateExistingDrawing(
        drawingPath,
        columnIndex,
        rowIndex,
        widthEmu,
        heightEmu,
        rId,
      );
    } else {
      drawing = _createNewDrawing(
        columnIndex,
        rowIndex,
        widthEmu,
        heightEmu,
        rId,
      );
    }

    _archiveFiles[drawingPath] = ArchiveFile(
      drawingPath,
      drawing.length,
      utf8.encode(drawing),
    );
  }

  String _updateExistingDrawing(
    String drawingPath,
    int columnIndex,
    int rowIndex,
    int width,
    int height,
    int rId,
  ) {
    var existingDrawing = utf8.decode(_archiveFiles[drawingPath]!.content);
    var xmlDoc = XmlDocument.parse(existingDrawing);
    var wsDrElement = xmlDoc.findAllElements('xdr:wsDr').first;

    var anchorElement = _createAnchorElement(
      columnIndex,
      rowIndex,
      width,
      height,
      rId,
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
  ) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>                                                                                                                                                                               
 <xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing"                                                                                                                                                           
           xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"                                                                                                                                                                           
           xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"                                                                                                                                                             
           xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart"                                                                                                                                                                          
           xmlns:cx="http://schemas.microsoft.com/office/drawing/2014/chartex"                                                                                                                                                                       
           xmlns:cx1="http://schemas.microsoft.com/office/drawing/2015/9/8/chartex"                                                                                                                                                                  
           xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"                                                                                                                                                                    
           xmlns:dgm="http://schemas.openxmlformats.org/drawingml/2006/diagram"                                                                                                                                                                      
           xmlns:x3Unk="http://schemas.microsoft.com/office/drawing/2010/slicer"                                                                                                                                                                     
           xmlns:sle15="http://schemas.microsoft.com/office/drawing/2012/slicer">                                                                                                                                                                    
   ${_createAnchorElement(columnIndex, rowIndex, width, height, rId)}                                                                                                                                                                                
 </xdr:wsDr>''';
  }

  String _createAnchorElement(
    int columnIndex,
    int rowIndex,
    int width,
    int height,
    int rId,
  ) {
    return '''<xdr:oneCellAnchor editAs="TwoCell">                                                                                                                                                                                                                   
     <xdr:from>                                                                                                                                                                                                                                      
       <xdr:col>$columnIndex</xdr:col>                                                                                                                                                                                                               
       <xdr:colOff>0</xdr:colOff>                                                                                                                                                                                                                    
       <xdr:row>$rowIndex</xdr:row>                                                                                                                                                                                                                  
       <xdr:rowOff>0</xdr:rowOff>                                                                                                                                                                                                                    
     </xdr:from>                                                                                                                                                                                                                                     
     <xdr:ext cx="$width" cy="$height"/>                                                                                                                                                                                                             
     <xdr:pic>                                                                                                                                                                                                                                       
       <xdr:nvPicPr>                                                                                                                                                                                                                                 
         <xdr:cNvPr id="$rId" name="image$rId.png"/>                                                                                                                                                                                                 
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
    int rId,
    ImageCellValue image,
  ) {
    _updateSheetRelationships(sheetRelsPath, drawingNumber);
    _updateDrawingRelationships(drawingRelsPath, rId, image);
  }

  void _updateSheetRelationships(String sheetRelsPath, int drawingNumber) {
    String sheetRels;
    var content = utf8.decode(_archiveFiles[sheetRelsPath]?.content ?? []);
    XmlDocument relsDoc;

    if (content.isEmpty) {
      relsDoc = _createNewRelationshipsDoc();
    } else {
      relsDoc = _ensureRelationshipsRoot(content);
    }

    var relsRoot = relsDoc.rootElement;
    _addDrawingRelationship(relsRoot, drawingNumber);

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

  void _addDrawingRelationship(XmlElement relsRoot, int drawingNumber) {
    if (relsRoot
        .findElements("Relationship")
        .none((element) => element.getAttribute("Id") == 'rId$drawingNumber')) {
      var newRel = XmlElement(XmlName('Relationship'), [
        XmlAttribute(XmlName('Id'), 'rId$drawingNumber'),
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
  ) {
    String drawingRels;
    if (_archiveFiles.containsKey(drawingRelsPath)) {
      drawingRels = _updateExistingDrawingRels(drawingRelsPath, rId, image);
    } else {
      drawingRels = _createNewDrawingRels(rId, image);
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
    String drawingRelsPath,
    int rId,
    ImageCellValue image,
  ) {
    final existingRels = utf8.decode(_archiveFiles[drawingRelsPath]!.content);

    final relsDoc = XmlDocument.parse(existingRels);

    final relationships = relsDoc.findAllElements('Relationships').first;

    final extension = _detectImageExtension(image.bytes);

    relationships.children.add(
      XmlElement(XmlName('Relationship'), [
        XmlAttribute(XmlName('Id'), 'rId$rId'),
        XmlAttribute(
          XmlName('Type'),
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image',
        ),
        XmlAttribute(XmlName('Target'), '../media/image$rId.$extension'),
      ]),
    );

    return relsDoc.toXmlString();
  }

  String _createNewDrawingRels(int rId, ImageCellValue image) {
    final extension = _detectImageExtension(image.bytes);

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship 
    Id="rId$rId" 
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" 
    Target="../media/image$rId.$extension"/>
</Relationships>''';
  }

  XmlElement _createCellElement(int columnIndex, int rowIndex) {
    return XmlElement(XmlName('c'), [
      XmlAttribute(XmlName('r'), getCellId(columnIndex, rowIndex)),
    ], []);
  }

  int _getAvailableRid(String sheetRelsPath) {
    final allRids = <int>[];

    <String, ArchiveFile>{
      ..._archiveFiles,
      ...Map.fromEntries(_excel._archive.map((it) => MapEntry(it.name, it))),
    }.forEach((path, archiveFile) {
      if (path.endsWith('.rels')) {
        final content = utf8.decode(archiveFile.content);
        if (content.isNotEmpty) {
          final doc = XmlDocument.parse(content);
          final rIds = doc
              .findAllElements('Relationship')
              .map((e) => e.getAttribute('Id'))
              .whereType<String>()
              .where((id) => id.startsWith('rId'))
              .map((id) => int.parse(id.substring(3)));
          allRids.addAll(rIds);
        }
      }
    });

    return allRids.isEmpty ? 1 : (allRids.reduce(max) + 1);
  }
}
