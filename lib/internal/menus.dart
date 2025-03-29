import 'dart:ui';

import 'package:editor/internal/environment.dart';
import 'package:editor/internal/file_utils.dart';
import 'package:editor/internal/paste.dart';
import 'package:editor/internal/preferences.dart';
import 'package:editor/internal/theme.dart';
import 'package:editor/widgets/context_menu.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:recase/recase.dart';

List<ContextMenuEntry> getFileMenuEntries(BuildContext context, WidgetRef ref) {
  final environment = ref.watch(editorEnvironmentProvider.notifier);
  final file = ref.watch(pathProvider);
  final recentFiles = ref.watch(recentFilesProvider);

  return [
    ContextMenuItem(
      label: "Create new",
      onActivate: () async {
        final shouldClose = await saveSafeGuard(context, ref);
        if (shouldClose) environment.closeFile();
      },
      shortcut: const SingleActivator(LogicalKeyboardKey.keyN, control: true),
    ),
    ContextMenuItem(
      label: "Open file",
      onActivate: () => openFile(context, ref, null),
      shortcut: const SingleActivator(LogicalKeyboardKey.keyO, control: true),
    ),
    ContextMenuNested(
      label: "Recent files",
      children:
          recentFiles.isNotEmpty
              ? [
                for (final recentFile in recentFiles.reversed)
                  ContextMenuItem(
                    label: basename(recentFile),
                    onActivate: () => openFile(context, ref, recentFile),
                  ),
                const ContextMenuDivider(),
                ContextMenuItem(
                  label: "Clear recents",
                  onActivate: () {
                    ref.read(recentFilesProvider.notifier).set([]);
                  },
                ),
              ]
              : const [ContextMenuItem(label: "No recent files")],
    ),
    const ContextMenuDivider(),
    ContextMenuItem(
      label: "Save",
      onActivate: () => saveFile(ref, false),
      shortcut: const SingleActivator(LogicalKeyboardKey.keyS, control: true),
    ),
    ContextMenuItem(
      label: "Save as...",
      onActivate: () => saveFile(ref, true),
      shortcut: const SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true),
    ),
    ContextMenuItem(
      label: "Save a copy",
      onActivate: () async {
        final fileName = ref.read(fileNameProvider);
        final nameParts = fileName.split(".");
        final (name, ext) =
            nameParts.length > 1
                ? (nameParts.sublist(0, nameParts.length - 1).join("."), nameParts.last)
                : (nameParts.single, null);
        final newFileName =
            file != null ? "$name copy${ext != null ? ".$ext" : ""}" : "$fileName copy.txt";

        final result = await FilePicker.platform.saveFile(
          dialogTitle: "Save a copy",
          fileName: newFileName,
        );
        if (result == null) return;

        await environment.saveFileCopy(result);
      },
      shortcut: const SingleActivator(LogicalKeyboardKey.keyS, control: true, alt: true),
    ),
    const ContextMenuDivider(),
    ContextMenuItem(
      label: "Quit",
      onActivate: () => ServicesBinding.instance.exitApplication(AppExitType.cancelable),
    ),
  ];
}

List<ContextMenuEntry> getEditMenuEntries(WidgetRef ref) {
  final controller = ref.watch(editorControllerProvider);
  final canPaste = ref.watch(pasteContentsProvider);
  final findController = ref.watch(findControllerProvider);

  return [
    ContextMenuListenableWrapper(
      listenable: controller,
      builder:
          () => ContextMenuItem(
            label: "Undo",
            onActivate: controller.canUndo ? controller.undo : null,
            shortcut: const SingleActivator(LogicalKeyboardKey.keyZ, control: true),
          ),
    ),
    ContextMenuListenableWrapper(
      listenable: controller,
      builder:
          () => ContextMenuItem(
            label: "Redo",
            onActivate: controller.canRedo ? controller.redo : null,
            shortcut: const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true),
          ),
    ),
    const ContextMenuDivider(),
    ContextMenuItem(
      label: "Copy",
      onActivate: controller.copy,
      shortcut: const SingleActivator(LogicalKeyboardKey.keyC, control: true),
    ),
    ContextMenuItem(
      label: "Cut",
      onActivate: controller.cut,
      shortcut: const SingleActivator(LogicalKeyboardKey.keyX, control: true),
    ),
    ContextMenuListenableWrapper(
      listenable: canPaste,
      builder:
          () => ContextMenuItem(
            label: "Paste",
            onActivate: canPaste.value ? controller.paste : null,
            shortcut: const SingleActivator(LogicalKeyboardKey.keyV, control: true),
          ),
    ),
    ContextMenuListenableWrapper(
      listenable: controller,
      builder:
          () => ContextMenuItem(
            label: "Delete",
            onActivate: !controller.selection.isCollapsed ? controller.deleteSelection : null,
            shortcut: const SingleActivator(LogicalKeyboardKey.cancel),
          ),
    ),
    const ContextMenuDivider(),
    ContextMenuItem(
      label: "Select all",
      onActivate: controller.selectAll,
      shortcut: const SingleActivator(LogicalKeyboardKey.keyA, control: true),
    ),
    const ContextMenuDivider(),
    ContextMenuItem(
      label: "Find",
      onActivate: findController.findMode,
      shortcut: const SingleActivator(LogicalKeyboardKey.keyF, control: true),
    ),
    ContextMenuItem(
      label: "Replace",
      onActivate: findController.replaceMode,
      shortcut: const SingleActivator(LogicalKeyboardKey.keyH, control: true),
    ),
  ];
}

List<ContextMenuEntry> getViewMenuEntries(WidgetRef ref) {
  final enableLineHighlighting = ref.watch(enableLineHighlightingProvider);
  final enableLineNumberColumn = ref.watch(enableLineNumberColumnProvider);
  final enableLineWrap = ref.watch(enableLineWrapProvider);

  return [
    ContextMenuItem(
      label: "Line highlighting",
      trailing:
          enableLineHighlighting ? const Icon(Icons.done, size: 16) : const SizedBox(width: 16),
      onActivate: () {
        ref.read(enableLineHighlightingProvider.notifier).set(!enableLineHighlighting);
      },
    ),
    ContextMenuItem(
      label: "Line number column",
      trailing:
          enableLineNumberColumn ? const Icon(Icons.done, size: 16) : const SizedBox(width: 16),
      onActivate: () {
        ref.read(enableLineNumberColumnProvider.notifier).set(!enableLineNumberColumn);
      },
    ),
    ContextMenuItem(
      label: "Word wrap",
      trailing: enableLineWrap ? const Icon(Icons.done, size: 16) : const SizedBox(width: 16),
      onActivate: () {
        ref.read(enableLineWrapProvider.notifier).set(!enableLineWrap);
      },
    ),
  ];
}

List<ContextMenuEntry> getPreferencesMenuEntries(WidgetRef ref) {
  final themeMode = ref.watch(themeModeProvider);
  final enableWindowEffects = ref.watch(enableWindowEffectsProvider);

  return [
    ContextMenuNested(
      label: "Theme mode",
      children: [
        for (final mode in ThemeMode.values)
          ContextMenuItem(
            label: mode.name.pascalCase,
            trailing:
                themeMode == mode ? const Icon(Icons.done, size: 16) : const SizedBox(width: 16),
            onActivate: () {
              ref.read(themeModeProvider.notifier).set(mode);
            },
          ),
      ],
    ),
    if (platformSupportsWindowEffects)
      ContextMenuItem(
        label: "Enable window effects",
        trailing:
            enableWindowEffects ? const Icon(Icons.done, size: 16) : const SizedBox(width: 16),
        onActivate: () {
          ref.read(enableWindowEffectsProvider.notifier).set(!enableWindowEffects);
        },
      ),
  ];
}
