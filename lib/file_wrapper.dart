import 'package:editor/editor.dart';
import 'package:editor/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EditorFileWrapper extends ConsumerStatefulWidget {
  const EditorFileWrapper({super.key});

  @override
  ConsumerState<EditorFileWrapper> createState() => _EditorFileWrapperState();
}

class _EditorFileWrapperState extends ConsumerState<EditorFileWrapper> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final contents = ref.read(fileContentsProvider);
    await _readAndSet(contents.value);
    ref.listenManual(fileContentsProvider, (p, n) {
      _readAndSet(n.value);
    });
  }

  Future<void> _readAndSet(String? contents) async {
    ref.read(textControllerProvider).text = contents ?? "";
    ref.read(undoControllerProvider).value = UndoHistoryValue.empty;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return const TextEditor();
  }
}
