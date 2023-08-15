import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:editor/editor/controller.dart';
import 'package:editor/internal/extensions.dart';
import 'package:flutter/material.dart';
import 'package:highlighting/languages/all.dart';
// ignore: implementation_imports
import 'package:highlighting/src/language.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

class EditorEnvironmentProvider extends InheritedWidget {
  final EditorEnvironment environment;

  const EditorEnvironmentProvider({
    required this.environment,
    required super.child,
  });

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return false;
  }
}

class EditorEnvironment {
  static EditorEnvironment of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<EditorEnvironmentProvider>()!
        .environment;
  }

  final EditorFile editorFile = EditorFile();
  final EditorTextEditingController textController =
      EditorTextEditingController();
  final UndoHistoryController undoController = UndoHistoryController();
  final ValueNotifier<Language?> _fileLanguage = ValueNotifier(null);

  bool _fileDeleted = false;

  EditorEnvironment({File? file}) {
    if (file != null) openFile(file);
    editorFile.changeStream.listen(_onFileChange);
  }

  Future<void> openFile(File file) async {
    await editorFile.openFile(file);
    _fileDeleted = false;

    textController.text = _normalizeLineBreaks(editorFile.fileContents);
    textController.selection = const TextSelection.collapsed(offset: 0);
    undoController.value = UndoHistoryValue.empty;

    _loadEditorLanguage();
  }

  String _normalizeLineBreaks(String? contents) {
    if (contents == null) return "";

    final lines = const LineSplitter().convert(contents);
    return lines.join("\n");
  }

  Future<void> _loadEditorLanguage() async {
    final langForExt = extensions[p.extension(editorFile.file!.path)];
    editorLanguage = allLanguages.values
        .firstWhereOrNull((e) => (e.name ?? e.id) == langForExt?.first);
  }

  void closeFile() {
    editorFile.closeFile();
    _fileDeleted = false;

    textController.text = "";
    textController.selection = const TextSelection.collapsed(offset: 0);
    undoController.value = UndoHistoryValue.empty;
    editorLanguage = null;
  }

  Language? get editorLanguage => _fileLanguage.value;
  ValueNotifier<Language?> get editorLanguageNotifier => _fileLanguage;
  set editorLanguage(Language? value) {
    textController.language = value;
    _fileLanguage.value = value;
  }

  bool get hasEdits {
    return editorFile.file != null
        ? textController.text.replaceAll('\r\n', '\n') !=
            editorFile.fileContents?.replaceAll('\r\n', '\n')
        : textController.text.isNotEmpty;
  }

  bool get fileDeleted => _fileDeleted && editorFile.file != null;

  void _onFileChange(ChangeType type) {
    switch (type) {
      case ChangeType.REMOVE:
        _fileDeleted = true;
      case ChangeType.MODIFY:
        if (hasEdits) return;

        textController.value =
            TextEditingValue(text: editorFile.fileContents ?? "");
        undoController.value = UndoHistoryValue.empty;
    }
  }
}

class EditorFile extends ChangeNotifier {
  File? _file;
  String? _fileContents;
  FileWatcher? _watcher;
  final _fileStreamController = StreamController<ChangeType>();
  StreamSubscription? _currentSub;

  Future<void> openFile(File file, {Encoding encoding = utf8}) async {
    _currentSub?.cancel();

    _file = file;
    _fileContents = await file.readAsString(encoding: encoding);
    _watcher = FileWatcher(file.path);

    _currentSub = _watcher!.events.listen(_pushEvent);
    await _watcher!.ready;
    notifyListeners();
  }

  void closeFile() {
    _currentSub?.cancel();

    _watcher = null;
    _fileContents = null;
    _file = null;

    notifyListeners();
  }

  void _pushEvent(WatchEvent event) {
    _fileStreamController.add(event.type);
  }

  File? get file => _file;
  String? get fileContents => _fileContents;

  Stream<ChangeType> get changeStream => _fileStreamController.stream;
}
