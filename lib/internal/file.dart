import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:editor/internal/extensions.dart';
import 'package:enough_convert/enough_convert.dart';
import 'package:path/path.dart' as p;
import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/re_highlight.dart';

typedef FileLanguage = (String, Mode);

enum EncodingType {
  utf8("UTF-8"),
  ascii("ASCII"),
  ansi("ANSI");

  final String displayName;

  const EncodingType(this.displayName);

  Encoding getEncoding({bool allowMalformed = false}) {
    return switch (this) {
      EncodingType.utf8 => Utf8Codec(allowMalformed: allowMalformed),
      EncodingType.ascii => AsciiCodec(allowInvalid: allowMalformed),
      EncodingType.ansi => Windows1252Codec(allowInvalid: allowMalformed),
    };
  }
}

class FileInfo {
  final String path;
  final FileLanguage? detectedLanguage;
  final EncodingType encoding;

  const FileInfo({required this.path, this.detectedLanguage, required this.encoding});
}

Future<(FileInfo, String?)> openFile(
  String path, {
  EncodingType encoding = EncodingType.utf8,
  bool allowMalformed = false,
}) async {
  final file = File(path);

  try {
    final fileContents = await file.readAsString(
      encoding: encoding.getEncoding(allowMalformed: allowMalformed),
    );

    return (
      FileInfo(path: path, detectedLanguage: _loadEditorLanguage(path), encoding: encoding),
      _normalizeLineBreaks(fileContents),
    );
  } on FileSystemException {
    return (FileInfo(path: path, encoding: encoding), null);
  }
}

String _normalizeLineBreaks(String? contents) {
  if (contents == null) return "";

  final lines = const LineSplitter().convert(contents);
  return lines.join("\n");
}

FileLanguage? _loadEditorLanguage(String path) {
  final highlight = Highlight();
  highlight.registerLanguages(builtinAllLanguages);
  final langForExt = extensions[p.extension(path)];
  final entry = builtinAllLanguages.entries.firstWhereOrNull(
    (e) =>
        e.value.name == langForExt?.first ||
        e.value.name == p.extension(path).substring(1) ||
        e.key == langForExt?.first ||
        e.key == p.extension(path).substring(1),
  );
  return entry != null ? (entry.key, entry.value) : null;
}

Future<bool> saveFile(
  String path,
  String contents, {
  EncodingType encoding = EncodingType.utf8,
}) async {
  final file = File(path);
  await file.writeAsString(contents, encoding: encoding.getEncoding());

  return true;
}
