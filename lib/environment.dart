import 'dart:async';
import 'dart:io';

import 'package:editor/highlight.dart';
import 'package:flutter/material.dart';
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
  final ValueNotifier<String?> _fileLanguage = ValueNotifier<String?>(null);
  bool _fileDeleted = false;

  EditorEnvironment({File? file}) {
    if (file != null) openFile(file);
    editorFile.changeStream.listen(_onFileChange);
  }

  Future<void> openFile(File file) async {
    await editorFile.openFile(file);
    _fileDeleted = false;

    textController.text = editorFile.fileContents ?? "";
    textController.selection = const TextSelection.collapsed(offset: 0);
    undoController.value = UndoHistoryValue.empty;
  }

  void closeFile() {
    editorFile.closeFile();
    _fileDeleted = false;

    textController.text = "";
    textController.selection = const TextSelection.collapsed(offset: 0);
    undoController.value = UndoHistoryValue.empty;
  }

  String? get editorLanguage => _fileLanguage.value;
  ValueNotifier<String?> get editorLanguageNotifier => _fileLanguage;
  set editorLanguage(String? value) {
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

  Future<void> openFile(File file) async {
    _currentSub?.cancel();

    _file = file;
    _fileContents = await file.readAsString();
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
