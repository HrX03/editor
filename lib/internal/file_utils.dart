import 'package:editor/internal/environment.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<bool> saveSafeGuard(BuildContext context, WidgetRef ref) async {
  final file = ref.read(pathProvider);
  final hasEdits = ref.read(hasEditsProvider);

  if (hasEdits) {
    final fileName = ref.read(fileNameProvider);
    final newFileName = file != null ? fileName : "$fileName.txt";
    final shouldSave = await showDialog<bool?>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Caution"),
            content: Text("Save changes for $newFileName before closing it?"),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Save"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Don't save"),
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ],
          ),
    );
    if (shouldSave == null) return false;
    if (shouldSave) {
      if (!await saveFile(ref, false)) return false;
    }
  }

  return true;
}

Future<bool> saveFile(WidgetRef ref, bool saveAs) async {
  final environment = ref.read(editorEnvironmentProvider.notifier);
  final file = ref.read(pathProvider);
  late String savePath;

  if (file == null || saveAs) {
    final fileName = ref.read(fileNameProvider);
    final newFileName = file != null ? fileName : "$fileName.txt";

    final result = await FilePicker.platform.saveFile(
      dialogTitle: saveAs ? "Save file as" : "Save file",
      fileName: newFileName,
    );
    if (result == null) return false;

    savePath = result;
  } else {
    savePath = file;
  }

  await environment.saveFile(savePath);
  return true;
}

Future<void> openFile(BuildContext context, WidgetRef ref, String? path) async {
  final environment = ref.read(editorEnvironmentProvider.notifier);
  final shouldOpenNewFile = await saveSafeGuard(context, ref);
  if (!shouldOpenNewFile) return;

  String pathToOpen;

  if (path == null) {
    final result = await FilePicker.platform.pickFiles();
    if (result == null) return;
    pathToOpen = result.files.first.path!;
  } else {
    pathToOpen = path;
  }

  environment.openFile(pathToOpen);
}
