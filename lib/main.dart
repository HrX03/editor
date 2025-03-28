import 'dart:io';

import 'package:editor/editor/editor.dart';
import 'package:editor/internal/environment.dart';
import 'package:editor/internal/paste.dart';
import 'package:editor/internal/preferences.dart';
import 'package:editor/internal/theme.dart';
import 'package:editor/widgets/context_menu.dart';
import 'package:editor/widgets/toolbar.dart';
import 'package:editor/widgets/window.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';
import 'package:recase/recase.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemTheme.accentColor.load();

  if (platformSupportsWindowEffects) {
    await Window.initialize();
    await Window.hideWindowControls();
  }
  await windowManager.ensureInitialized();

  const options = WindowOptions(
    minimumSize: Size(480, 360),
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
    backgroundColor: Colors.transparent,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    /* if (platformSupportsWindowEffects) {
      await Window.setEffect(effect: WindowEffect.mica);
    } */
    await windowManager.show();
    await windowManager.focus();
  });

  final file = args.isNotEmpty ? File(args.first) : null;
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(sharedPreferences)],
      child: MainApp(file: file),
    ),
  );
}

class MainApp extends ConsumerWidget {
  final File? file;

  const MainApp({this.file, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return StreamBuilder<SystemAccentColor>(
      stream: SystemTheme.onChange,
      builder: (context, snapshot) {
        final systemTheme = snapshot.data ?? SystemTheme.accentColor;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(
            colorScheme: buildSchemeForSystemAccent(systemTheme, Brightness.light),
            editorTheme: atomOneLightTheme,
          ),
          darkTheme: buildTheme(
            colorScheme: buildSchemeForSystemAccent(systemTheme, Brightness.dark),
            editorTheme: atomOneDarkTheme,
          ),
          themeMode: themeMode,
          builder:
              (cnotext, child) => ResponsiveBreakpoints.builder(
                child: child!,
                breakpoints: [
                  const Breakpoint(start: 0, end: 640, name: 'COMPACT'),
                  const Breakpoint(start: 641, end: double.infinity, name: 'FULL'),
                ],
              ),
          home: _EditorApp(initialFile: file),
        );
      },
    );
  }
}

class _EditorApp extends ConsumerStatefulWidget {
  final File? initialFile;

  const _EditorApp({this.initialFile});

  @override
  ConsumerState<_EditorApp> createState() => _EditorAppState();
}

class _EditorAppState extends ConsumerState<_EditorApp> {
  @override
  void initState() {
    super.initState();
    if (widget.initialFile == null) return;
    ref.read(editorEnvironmentProvider.notifier).openFile(widget.initialFile!);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorEnvironmentProvider).value!;
    final environment = ref.watch(editorEnvironmentProvider.notifier);
    final controller = ref.watch(editorControllerProvider);
    final canPaste = ref.watch(pasteContentsProvider);
    final findController = ref.watch(findControllerProvider);
    final enableWindowEffects =
        platformSupportsWindowEffects && ref.watch(enableWindowEffectsProvider);

    return WindowEffectSetter(
      effect: WindowEffect.mica,
      enableEffects: enableWindowEffects,
      child: Scaffold(
        backgroundColor:
            enableWindowEffects ? Colors.transparent : Theme.of(context).colorScheme.surface,
        appBar: WindowBar(
          leading: CodeEditorTapRegion(
            child: EditorContextMenu(
              entries: [
                ContextMenuNested(
                  label: "File",
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    textStyle: Theme.of(context).primaryTextTheme.bodySmall,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  children: [
                    ContextMenuItem(
                      label: "Create new",
                      onActivate: environment.closeFile,
                      shortcut: const SingleActivator(LogicalKeyboardKey.keyN, control: true),
                    ),
                    ContextMenuItem(
                      label: "Open from disk",
                      onActivate: () async {
                        final result = await FilePicker.platform.pickFiles();
                        if (result == null) return;

                        environment.openFile(File(result.files.first.path!));
                      },
                      shortcut: const SingleActivator(LogicalKeyboardKey.keyO, control: true),
                    ),
                  ],
                ),
                ContextMenuNested(
                  label: "Edit",
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    textStyle: Theme.of(context).primaryTextTheme.bodySmall,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  children: [
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
                            shortcut: const SingleActivator(
                              LogicalKeyboardKey.keyZ,
                              control: true,
                              shift: true,
                            ),
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
                            onActivate:
                                !controller.selection.isCollapsed
                                    ? controller.deleteSelection
                                    : null,
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
                  ],
                ),
                ContextMenuNested(
                  label: "View",
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    textStyle: Theme.of(context).primaryTextTheme.bodySmall,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  children: [
                    ContextMenuItem(
                      label: "Line highlighting",
                      trailing:
                          ref.watch(enableLineHighlightingProvider)
                              ? const Icon(Icons.done, size: 16)
                              : const SizedBox(width: 16),
                      onActivate: () {
                        final value = ref.read(enableLineHighlightingProvider);
                        ref.read(enableLineHighlightingProvider.notifier).set(!value);
                      },
                    ),
                    ContextMenuItem(
                      label: "Line number column",
                      trailing:
                          ref.watch(enableLineNumberColumnProvider)
                              ? const Icon(Icons.done, size: 16)
                              : const SizedBox(width: 16),
                      onActivate: () {
                        final value = ref.read(enableLineNumberColumnProvider);
                        ref.read(enableLineNumberColumnProvider.notifier).set(!value);
                      },
                    ),
                    ContextMenuItem(
                      label: "Word wrap",
                      trailing:
                          ref.watch(enableLineWrapProvider)
                              ? const Icon(Icons.done, size: 16)
                              : const SizedBox(width: 16),
                      onActivate: () {
                        final value = ref.read(enableLineWrapProvider);
                        ref.read(enableLineWrapProvider.notifier).set(!value);
                      },
                    ),
                  ],
                ),
                ContextMenuNested(
                  label: "Preferences",
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    textStyle: Theme.of(context).primaryTextTheme.bodySmall,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  children: [
                    ContextMenuNested(
                      label: "Theme mode",
                      children: [
                        for (final mode in ThemeMode.values)
                          ContextMenuItem(
                            label: mode.name.pascalCase,
                            trailing:
                                ref.watch(themeModeProvider) == mode
                                    ? const Icon(Icons.done, size: 16)
                                    : const SizedBox(width: 16),
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
                            ref.watch(enableWindowEffectsProvider)
                                ? const Icon(Icons.done, size: 16)
                                : const SizedBox(width: 16),
                        onActivate: () {
                          final value = ref.read(enableWindowEffectsProvider);
                          ref.read(enableWindowEffectsProvider.notifier).set(!value);
                        },
                      ),
                  ],
                ),
              ],
              menuStyle: getMenuStyle(),
              menuItemStyle: getMenuItemStyle(Theme.of(context)),
              nestedMenuItemStyle: getNestedMenuItemStyle(Theme.of(context)),
            ),
          ),
          title: const WindowTitle(),
        ),
        body:
            state.encodingIssue == false
                ? const TextEditor()
                : SizedBox.expand(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Could not open file"),
                      if (state.allowsMalformed)
                        const Text("Try changing the file encoding")
                      else
                        const Text("Try reopening the file with malformed characters"),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed:
                            !state.allowsMalformed
                                ? () {
                                  environment.reopenMalformed();
                                }
                                : null,
                        child: const Text("Reopen with malformed characters"),
                      ),
                    ],
                  ),
                ),
        bottomNavigationBar: const SizedBox(height: 24, child: EditorToolbar()),
      ),
    );
  }
}
