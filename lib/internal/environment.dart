import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:editor/internal/extensions.dart';
import 'package:editor/internal/value.dart';
import 'package:enough_convert/enough_convert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/re_highlight.dart';

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

typedef EditorState =
    ({
      File? file,
      String? fileContents,
      (String, Mode)? fileLanguage,
      EncodingType encoding,
      bool allowsMalformed,
      bool encodingIssue,
    });

final editorControllerProvider = ChangeNotifierProvider((ref) {
  final controller = ref.watch(
    editorEnvironmentProvider.notifier.select((value) => value._textController),
  );

  return controller;
});

final findControllerProvider = ChangeNotifierProvider((ref) {
  final controller = ref.watch(
    editorEnvironmentProvider.notifier.select((value) => value._findController),
  );

  return controller;
});

final undoControllerProvider = ChangeNotifierProvider((ref) {
  final controller = ref.watch(
    editorEnvironmentProvider.notifier.select((value) => value._undoController),
  );

  return controller;
});

final fileLanguageProvider = Provider((ref) {
  final fileLanguage = ref.watch(
    editorEnvironmentProvider.select((value) => value.value!.fileLanguage),
  );

  return fileLanguage;
});

final encodingProvider = Provider((ref) {
  final encoding = ref.watch(editorEnvironmentProvider.select((value) => value.value!.encoding));

  return encoding;
});

final fileProvider = Provider((ref) {
  final file = ref.watch(editorEnvironmentProvider.select((value) => value.value!.file));

  return file;
});

final fileContentsProvider = Provider((ref) {
  final file = ref.watch(editorEnvironmentProvider.select((value) => value.value!.fileContents));

  return file;
});

final hasEditsProvider = Provider((ref) {
  final controller = ref.watch(editorControllerProvider);
  final fileContents = ref.watch(
    editorEnvironmentProvider.select((value) => value.value!.fileContents),
  );

  if (fileContents == null) return controller.text.isNotEmpty;

  final controllerText = EditorEnvironment._normalizeLineBreaks(controller.text);
  final fileContentsNormalized = EditorEnvironment._normalizeLineBreaks(fileContents);

  return controllerText != fileContentsNormalized;
});

final editorEnvironmentProvider = AsyncNotifierProvider<EditorEnvironment, EditorState>(
  () => EditorEnvironment(),
);

class EditorEnvironment extends AsyncNotifier<EditorState> {
  final _textController = CodeLineEditingController();
  late final _findController = CodeFindController(_textController);
  final _undoController = UndoHistoryController();

  @override
  EditorState build() => (
    file: null,
    fileContents: null,
    fileLanguage: null,
    encoding: EncodingType.utf8,
    allowsMalformed: false,
    encodingIssue: false,
  );

  Future<void> openFile(File file, {EncodingType encoding = EncodingType.utf8}) async {
    final editorState = await _loadFile(file, encoding: encoding);
    state = AsyncData(editorState);
  }

  Future<void> reopenMalformed() async {
    if (state.value == null || state.value?.file == null) {
      throw Exception("No file has been opened");
    }

    final file = state.value!.file!;
    final encoding = state.value!.encoding;

    final editorState = await _loadFile(file, encoding: encoding, allowMalformed: true);
    state = AsyncData(editorState);
  }

  Future<void> reopenWithEncoding(EncodingType encoding) async {
    if (state.value == null || state.value?.file == null) {
      throw Exception("No file has been opened");
    }

    final file = state.value!.file!;

    final editorState = await _loadFile(file, encoding: encoding);
    state = AsyncData(editorState);
  }

  void closeFile() {
    _textController.text = "";
    _textController.selection = const CodeLineSelection.collapsed(index: 0, offset: 0);
    _undoController.value = UndoHistoryValue.empty;

    state = const AsyncData((
      file: null,
      fileContents: null,
      fileLanguage: null,
      encoding: EncodingType.utf8,
      allowsMalformed: false,
      encodingIssue: false,
    ));
  }

  void setLanguage((String, Mode)? language) {
    final currState = state.value!;
    state = AsyncData(
      currState.copyWith(fileLanguage: language != null ? Value(language) : const Value.erase()),
    );
  }

  Future<EditorState> _loadFile(
    File file, {
    EncodingType encoding = EncodingType.utf8,
    bool allowMalformed = false,
  }) async {
    String? fileContents;
    bool encodingIssue = false;

    try {
      fileContents = await file.readAsString(
        encoding: encoding.getEncoding(allowMalformed: allowMalformed),
      );
    } on FileSystemException {
      fileContents = null;
      encodingIssue = true;
    }

    _textController.text = _normalizeLineBreaks(fileContents);
    _textController.selection = const CodeLineSelection.collapsed(index: 0, offset: 0);
    _undoController.value = UndoHistoryValue.empty;

    final language = _loadEditorLanguage(file);
    // _textController.language = language;

    return (
      file: file,
      fileContents: fileContents,
      fileLanguage: language,
      encoding: encoding,
      allowsMalformed: allowMalformed,
      encodingIssue: encodingIssue,
    );
  }

  static String _normalizeLineBreaks(String? contents) {
    if (contents == null) return "";

    final lines = const LineSplitter().convert(contents);
    return lines.join("\n");
  }

  (String, Mode)? _loadEditorLanguage(File? file) {
    final highlight = Highlight();
    highlight.registerLanguages(builtinAllLanguages);
    final langForExt = extensions[p.extension(file!.path)];
    final entry = builtinAllLanguages.entries.firstWhereOrNull(
      (e) =>
          e.value.name == langForExt?.first ||
          e.value.name == p.extension(file.path).substring(1) ||
          e.key == langForExt?.first ||
          e.key == p.extension(file.path).substring(1),
    );
    return entry != null ? (entry.key, entry.value) : null;
  }
}

extension on EditorState {
  EditorState copyWith({
    Value<File?>? file,
    Value<String?>? fileContents,
    Value<(String, Mode)?>? fileLanguage,
    Value<EncodingType?>? encoding,
    Value<bool>? allowsMalformed,
    Value<bool>? encodingIssue,
  }) {
    return (
      file: Value.handleValue(file, null, this.file),
      fileContents: Value.handleValue(fileContents, null, this.fileContents),
      fileLanguage: Value.handleValue(fileLanguage, null, this.fileLanguage),
      encoding: Value.handleValue(encoding, EncodingType.utf8) ?? this.encoding,
      allowsMalformed: Value.handleValue<bool>(allowsMalformed, false) ?? this.allowsMalformed,
      encodingIssue: Value.handleValue<bool>(encodingIssue, false) ?? this.encodingIssue,
    );
  }
}
