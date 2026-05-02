part of excel;

String _escapeXml(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

class _SharedStringsMaintainer {
  final Map<SharedString, _IndexingHolder> _map =
      <SharedString, _IndexingHolder>{};
  final Map<String, SharedString> _mapString = <String, SharedString>{};
  final List<SharedString> _list = <SharedString>[];
  int _index = 0;

  _SharedStringsMaintainer._();

  SharedString? tryFind(String val) {
    return _mapString[val];
  }

  SharedString addFromString(String val) {
    final newSharedString = SharedString._fromText(val);

    add(newSharedString, val);
    return newSharedString;
  }

  void add(SharedString val, String key) {
    _map[val]?.increaseCount();
    _list.add(val);
    _map.putIfAbsent(val, () {
      _mapString[key] = val;
      return _IndexingHolder(_index++);
    });
  }

  int indexOf(SharedString val) {
    return _map[val] != null ? _map[val]!.index : -1;
  }

  SharedString? value(int i) {
    if (i < _list.length) {
      return _list[i];
    } else {
      return null;
    }
  }

  void forEach(void Function(SharedString string, int count) fn) {
    _map.forEach((string, holder) {
      fn(string, holder.count);
    });
  }

  void clear() {
    _index = 0;
    _list.clear();
    _map.clear();
    _mapString.clear();
  }
}

class _IndexingHolder {
  final int index;
  int count;

  _IndexingHolder(this.index, [int _count = 1]) : count = _count;

  void increaseCount() {
    this.count += 1;
  }
}

class SharedString {
  XmlElement? _node;
  final String? _text;
  late final int _hashCode = toXmlString().hashCode;

  SharedString({required XmlElement node}) : _node = node, _text = null;

  SharedString._fromText(String text) : _node = null, _text = text;

  XmlElement get node {
    return _node ??= XmlElement(XmlName('si'), [], [
      XmlElement(
        XmlName('t'),
        [XmlAttribute(XmlName("space", "xml"), "preserve")],
        [XmlText(_text!)],
      ),
    ]);
  }

  @override
  String toString() {
    assert(
      false,
      'prefer stringValue over SharedString.toString() in development',
    );
    return stringValue;
  }

  TextSpan get textSpan {
    if (_node == null) {
      return TextSpan(text: _text);
    }

    bool readOnOff(XmlElement element) {
      final value = element.getAttribute('val')?.trim().toLowerCase();
      return switch (value) {
        null || '' => true,
        '0' || 'false' || 'off' => false,
        _ => true,
      };
    }

    Underline readUnderline(XmlElement element) {
      return switch (element.getAttribute('val')?.trim().toLowerCase()) {
        'none' => Underline.None,
        'double' || 'doubleaccounting' => Underline.Double,
        _ => Underline.Single,
      };
    }

    int getDouble(XmlElement element) {
      // Should be double
      return double.parse(element.getAttribute('val')!).toInt();
    }

    String? text;
    List<TextSpan>? children;

    /// SharedStringItem
    /// https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.spreadsheet.sharedstringitem?view=openxml-3.0.1
    assert(node.localName == 'si'); //18.4.8 si (String Item)

    for (final child in node.childElements) {
      switch (child.localName) {
        /// Text
        /// https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.spreadsheet.text?view=openxml-3.0.1
        case 't': //18.4.12 t (Text)
          text = (text ?? '') + child.innerText;
          break;

        /// Rich Text Run
        /// https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.spreadsheet.run?view=openxml-3.0.1
        case 'r': //18.4.4 r (Rich Text Run)
          var style = CellStyle();
          for (final runChild in child.childElements) {
            switch (runChild.localName) {
              /// RunProperties
              /// https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.spreadsheet.runproperties?view=openxml-3.0.1
              case 'rPr':
                for (final runProperty in runChild.childElements) {
                  switch (runProperty.localName) {
                    case 'b': //18.8.2 b (Bold)
                      style = style.copyWith(boldVal: readOnOff(runProperty));
                      break;
                    case 'i': //18.8.26 i (Italic)
                      style = style.copyWith(italicVal: readOnOff(runProperty));
                      break;
                    case 'strike': //18.8.40 strike (Strike Through)
                      style = style.copyWith(
                        strikethroughVal: readOnOff(runProperty),
                      );
                      break;
                    case 'u': //18.4.13 u (Underline)
                      style = style.copyWith(
                        underlineVal: readUnderline(runProperty),
                      );
                      break;
                    case 'sz': //18.4.11 sz (Font Size)
                      style = style.copyWith(
                        fontSizeVal: getDouble(runProperty),
                      );
                      break;
                    case 'rFont': //18.4.5 rFont (Font)
                      style = style.copyWith(
                        fontFamilyVal: runProperty.getAttribute('val'),
                      );
                      break;
                    case 'color': //18.3.1.15 color (Data Bar Color)
                      style = style.copyWith(
                        fontColorHexVal: runProperty
                            .getAttribute('rgb')
                            ?.excelColor,
                      );
                      break;
                  }
                }
                break;

              /// Text
              case 't': //18.4.12 t (Text)
                if (children == null) children = [];
                children.add(TextSpan(text: runChild.innerText, style: style));
                break;
            }
          }
          break;

        /// Phonetic Run
        /// https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.spreadsheet.phoneticrun?view=openxml-3.0.1
        case 'rPh': //18.4.6 rPh (Phonetic Run)
          break;
      }
    }

    return TextSpan(text: text, children: children);
  }

  String get stringValue {
    if (_text != null) {
      return _text;
    }

    var buffer = StringBuffer();
    node.findAllElements('t').forEach((child) {
      if (child.parentElement == null ||
          child.parentElement!.name.local != 'rPh') {
        buffer.write(Parser._parseValue(child));
      }
    });
    return buffer.toString();
  }

  String toXmlString() {
    if (_node == null) {
      return '<si><t xml:space="preserve">${_escapeXml(_text!)}</t></si>';
    }
    return node.toString();
  }

  @override
  int get hashCode => _hashCode;

  @override
  operator ==(Object other) {
    return other is SharedString &&
        other.hashCode == _hashCode &&
        other.stringValue == stringValue;
  }

  bool matches(String value) {
    return value.isNotEmpty && value == stringValue;
  }
}

class TextSpan {
  final String? text;
  final List<TextSpan>? children;
  final CellStyle? style;

  const TextSpan({this.children, this.text, this.style});

  @override
  String toString() {
    String r = '';
    if (text != null) r += text!;
    if (children != null) r += children!.join();
    return r;
  }

  @override
  operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is TextSpan &&
        other.text == text &&
        other.style == style &&
        ListEquality().equals(other.children, children);
  }

  @override
  int get hashCode =>
      Object.hash(text, style, Object.hashAll(children ?? const []));
}
