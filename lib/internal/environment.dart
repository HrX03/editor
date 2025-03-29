import 'dart:async';
import 'dart:math';

import 'package:editor/internal/file.dart' as file;
import 'package:editor/internal/preferences.dart';
import 'package:editor/internal/value.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:re_editor/re_editor.dart';

typedef EditorState =
    ({
      file.FileInfo? fileInfo,
      String? fileRawContents,
      file.FileLanguage? editorLanguage,
      bool allowMalformedCharacters,
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

final editorLanguageProvider = Provider((ref) {
  final fileLanguage = ref.watch(
    editorEnvironmentProvider.select((value) => value.value!.editorLanguage),
  );

  return fileLanguage;
});

final encodingProvider = Provider((ref) {
  final encoding = ref.watch(
    editorEnvironmentProvider.select((value) => value.value!.fileInfo?.encoding),
  );

  return encoding;
});

final pathProvider = Provider((ref) {
  final path = ref.watch(editorEnvironmentProvider.select((value) => value.value!.fileInfo?.path));

  return path;
});

final fileInfoProvider = Provider((ref) {
  final info = ref.watch(editorEnvironmentProvider.select((value) => value.value!.fileInfo));

  return info;
});

final fileContentsProvider = Provider((ref) {
  final contents = ref.watch(
    editorEnvironmentProvider.select((value) => value.value!.fileRawContents),
  );

  return contents;
});

final fileNameProvider = Provider((ref) {
  final file = ref.watch(fileInfoProvider);
  final textController = ref.watch(editorControllerProvider);

  final firstLine = textController.codeLines.first.text;

  String fileName = firstLine.substring(0, min(firstLine.length, 40)).trim();
  fileName = fileName.isNotEmpty ? fileName : "Untitled";

  return file != null ? p.basename(file.path) : fileName;
});

final hasEditsProvider = Provider((ref) {
  final controller = ref.watch(editorControllerProvider);
  final fileContents = ref.watch(fileContentsProvider);

  if (fileContents == null) return controller.text.isNotEmpty;

  return controller.text != fileContents;
});

final editorEnvironmentProvider = AsyncNotifierProvider<EditorEnvironment, EditorState>(
  () => EditorEnvironment(),
);

class EditorEnvironment extends AsyncNotifier<EditorState> {
  final _textController = CodeLineEditingController();
  late final _findController = CodeFindController(_textController);

  @override
  EditorState build() => (
    fileInfo: null,
    fileRawContents: null,
    editorLanguage: null,
    allowMalformedCharacters: false,
  );

  Future<void> openFile(String path, {file.EncodingType encoding = file.EncodingType.utf8}) async {
    final editorState = await _loadFile(path, encoding: encoding);

    List<String> recentFiles = ref.read(recentFilesProvider);
    if (recentFiles.contains(path)) {
      recentFiles.remove(path);
    }
    recentFiles.add(path);
    if (recentFiles.length > 10) {
      recentFiles = recentFiles.sublist(0, 10);
    }
    ref.read(recentFilesProvider.notifier).set(recentFiles);

    state = AsyncData(editorState);
  }

  Future<void> reopenMalformed() async {
    if (state.value == null || state.value?.fileInfo == null) {
      throw Exception("No file has been opened");
    }

    final file = state.value!.fileInfo!.path;
    final encoding = state.value!.fileInfo!.encoding;

    final editorState = await _loadFile(file, encoding: encoding, allowMalformed: true);
    state = AsyncData(editorState);
  }

  Future<void> reopenWithEncoding(file.EncodingType encoding) async {
    if (state.value == null || state.value?.fileInfo == null) {
      throw Exception("No file has been opened");
    }

    final file = state.value!.fileInfo!.path;

    final editorState = await _loadFile(file, encoding: encoding);
    state = AsyncData(editorState);
  }

  void closeFile() {
    _textController.text = "";
    _textController.selection = const CodeLineSelection.collapsed(index: 0, offset: 0);

    state = const AsyncData((
      fileInfo: null,
      fileRawContents: null,
      editorLanguage: null,
      allowMalformedCharacters: false,
    ));
  }

  Future<void> saveFile(String path) async {
    final currState = state.value!;
    final encoding = currState.fileInfo?.encoding ?? file.EncodingType.utf8;

    await file.saveFile(path, _textController.text, encoding: encoding);

    state = AsyncData(
      currState.copyWith(
        fileInfo: Value(
          file.FileInfo(path: path, detectedLanguage: currState.editorLanguage, encoding: encoding),
        ),
        fileRawContents: Value(_textController.text),
      ),
    );
  }

  Future<void> saveFileCopy(String path) async {
    final currState = state.value!;

    await file.saveFile(
      path,
      _textController.text,
      encoding: currState.fileInfo?.encoding ?? file.EncodingType.utf8,
    );
  }

  void setLanguage(file.FileLanguage? language) {
    final currState = state.value!;
    state = AsyncData(
      currState.copyWith(editorLanguage: language != null ? Value(language) : const Value.erase()),
    );
  }

  Future<EditorState> _loadFile(
    String path, {
    file.EncodingType encoding = file.EncodingType.utf8,
    bool allowMalformed = false,
  }) async {
    final (info, contents) = await file.openFile(
      path,
      encoding: encoding,
      allowMalformed: allowMalformed,
    );

    _textController.text = contents ?? "";
    _textController.selection = const CodeLineSelection.collapsed(index: 0, offset: 0);

    return (
      fileInfo: info,
      fileRawContents: contents,
      editorLanguage: info.detectedLanguage,
      allowMalformedCharacters: allowMalformed,
    );
  }
}

extension on EditorState {
  EditorState copyWith({
    Value<file.FileInfo?>? fileInfo,
    Value<String?>? fileRawContents,
    Value<file.FileLanguage?>? editorLanguage,
    Value<bool>? allowMalformedCharacters,
  }) {
    return (
      fileInfo: Value.handleValue(fileInfo, null, this.fileInfo),
      fileRawContents: Value.handleValue(fileRawContents, null, this.fileRawContents),
      editorLanguage: Value.handleValue(editorLanguage, null, this.editorLanguage),
      allowMalformedCharacters:
          Value.handleValue(allowMalformedCharacters, false, this.allowMalformedCharacters)!,
    );
  }
}
