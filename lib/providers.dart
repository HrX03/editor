import 'dart:io';

import 'package:editor/highlight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watcher/watcher.dart';

final textControllerProvider = ChangeNotifierProvider(
  (ref) => EditorTextEditingController(),
);

final undoControllerProvider = ChangeNotifierProvider(
  (ref) => UndoHistoryController(),
);

final currentLanguageProvider = StateProvider<String?>((ref) => null);

late final StateProvider<File?> currentFileProvider;
void initFileProvider(File? file) {
  currentFileProvider = StateProvider<File?>((ref) => file);
}

final hasEditsProvider = Provider((ref) {
  final file = ref.watch(currentFileProvider);
  final undoController = ref.watch(undoControllerProvider);
  final textController = ref.watch(textControllerProvider);

  return file != null
      ? undoController.value.canUndo
      : textController.text.isNotEmpty;
});

final fileContentsProvider = FutureProvider((ref) async {
  final file = ref.watch(currentFileProvider);
  ref.watch(fileWatcherProvider(file));

  return file?.readAsString();
});

final fileWatcherProvider =
    StreamProvider.family<WatchEvent, File?>((ref, file) {
  if (file == null) return const Stream.empty();

  return FileWatcher(file.path).events;
});
