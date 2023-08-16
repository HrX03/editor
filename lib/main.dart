import 'dart:io';

import 'package:editor/editor/editor.dart';
import 'package:editor/internal/environment.dart';
import 'package:editor/internal/preferences.dart';
import 'package:editor/internal/theme.dart';
import 'package:editor/widgets/context_menu.dart';
import 'package:editor/widgets/toolbar.dart';
import 'package:editor/widgets/window.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_highlighter/themes/atom-one-dark.dart';
import 'package:flutter_highlighter/themes/atom-one-light.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:recase/recase.dart';
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
    if (platformSupportsWindowEffects) {
      await Window.setEffect(effect: WindowEffect.mica);
    }
    await windowManager.show();
    await windowManager.focus();
  });

  final file = args.isNotEmpty ? File(args.first) : null;
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
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
            colorScheme:
                buildSchemeForSystemAccent(systemTheme, Brightness.light),
            editorTheme: atomOneLightTheme,
          ),
          darkTheme: buildTheme(
            colorScheme:
                buildSchemeForSystemAccent(systemTheme, Brightness.dark),
            editorTheme: atomOneDarkTheme,
          ),
          themeMode: themeMode,
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

    return WindowEffectSetter(
      effect: WindowEffect.mica,
      enableEffects: platformSupportsWindowEffects,
      child: Scaffold(
        backgroundColor: platformSupportsWindowEffects
            ? Colors.transparent
            : Theme.of(context).colorScheme.background,
        appBar: WindowBar(
          title: EditorContextMenu(
            entries: [
              ContextMenuNested(
                label: "File",
                children: [
                  ContextMenuItem(
                    label: "Create new",
                    onActivate: environment.closeFile,
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyN,
                      control: true,
                    ),
                  ),
                  ContextMenuItem(
                    label: "Open from disk",
                    onActivate: () async {
                      final result = await FilePicker.platform.pickFiles();
                      if (result == null) return;

                      environment.openFile(File(result.files.first.path!));
                    },
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyO,
                      control: true,
                    ),
                  ),
                ],
              ),
              ContextMenuNested(
                label: "Preferences",
                children: [
                  ContextMenuItem(
                    label: "Show line highlighting",
                    trailing: ref.watch(enableLineHighlightingProvider)
                        ? const Icon(Icons.done, size: 16)
                        : const SizedBox(width: 16),
                    onActivate: () {
                      final value = ref.read(enableLineHighlightingProvider);
                      ref
                          .read(enableLineHighlightingProvider.notifier)
                          .set(!value);
                    },
                  ),
                  ContextMenuItem(
                    label: "Show line number column",
                    trailing: ref.watch(enableLineNumberColumnProvider)
                        ? const Icon(Icons.done, size: 16)
                        : const SizedBox(width: 16),
                    onActivate: () {
                      final value = ref.read(enableLineNumberColumnProvider);
                      ref
                          .read(enableLineNumberColumnProvider.notifier)
                          .set(!value);
                    },
                  ),
                  const ContextMenuDivider(),
                  ContextMenuNested(
                    label: "Theme mode",
                    children: [
                      for (final mode in ThemeMode.values)
                        ContextMenuItem(
                          label: mode.name.pascalCase,
                          trailing: ref.watch(themeModeProvider) == mode
                              ? const Icon(Icons.done, size: 16)
                              : const SizedBox(width: 16),
                          onActivate: () {
                            ref.read(themeModeProvider.notifier).set(mode);
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ],
            menuStyle: const MenuStyle(
              padding: MaterialStatePropertyAll(
                EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            menuItemStyle: TextButton.styleFrom(
              minimumSize: const Size(220, 40),
              textStyle: Theme.of(context).primaryTextTheme.bodyMedium,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            nestedMenuItemStyle: TextButton.styleFrom(
              minimumSize: const Size(0, 40),
              textStyle: Theme.of(context).primaryTextTheme.bodyMedium,
              padding: const EdgeInsets.only(left: 16, right: 8),
            ),
            builder: (context, controller) {
              return TextButton(
                onPressed:
                    controller.isOpen ? controller.close : controller.open,
                style: TextButton.styleFrom(
                  shape: const RoundedRectangleBorder(),
                  textStyle: const TextStyle(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  foregroundColor: Theme.of(context).colorScheme.onBackground,
                ),
                child: const WindowTitle(),
              );
            },
          ),
        ),
        body: state.encodingIssue == false
            ? Theme(
                data: Theme.of(context).copyWith(
                  textTheme: GoogleFonts.firaCodeTextTheme(),
                ),
                child: const TextEditor(),
              )
            : SizedBox.expand(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Could not open file"),
                    if (state.allowsMalformed)
                      const Text("Try changing the file encoding")
                    else
                      const Text(
                        "Try reopening the file with malformed characters",
                      ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: !state.allowsMalformed
                          ? () {
                              environment.reopenMalformed();
                            }
                          : null,
                      child: const Text("Reopen with malformed characters"),
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: const SizedBox(
          height: 24,
          child: EditorToolbar(),
        ),
      ),
    );
  }
}
