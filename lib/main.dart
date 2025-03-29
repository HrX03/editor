import 'package:editor/editor/editor.dart';
import 'package:editor/internal/environment.dart';
import 'package:editor/internal/file_utils.dart';
import 'package:editor/internal/menus.dart';
import 'package:editor/internal/preferences.dart';
import 'package:editor/internal/theme.dart';
import 'package:editor/widgets/context_menu.dart';
import 'package:editor/widgets/toolbar.dart';
import 'package:editor/widgets/window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_window_close/flutter_window_close.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';
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
    await windowManager.show();
    await windowManager.focus();
  });

  final path = args.isNotEmpty ? args.first : null;
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(sharedPreferences)],
      child: MainApp(path: path),
    ),
  );
}

class MainApp extends ConsumerWidget {
  final String? path;

  const MainApp({this.path, super.key});

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
          home: _EditorApp(initialPath: path),
        );
      },
    );
  }
}

class _EditorApp extends ConsumerStatefulWidget {
  final String? initialPath;

  const _EditorApp({this.initialPath});

  @override
  ConsumerState<_EditorApp> createState() => _EditorAppState();
}

class _EditorAppState extends ConsumerState<_EditorApp> {
  @override
  void initState() {
    super.initState();
    if (widget.initialPath == null) return;
    ref.read(editorEnvironmentProvider.notifier).openFile(widget.initialPath!);

    FlutterWindowClose.setWindowShouldCloseHandler(() => saveSafeGuard(context, ref));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorEnvironmentProvider).value!;
    final environment = ref.watch(editorEnvironmentProvider.notifier);
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
                  children: getFileMenuEntries(context, ref),
                ),
                ContextMenuNested(
                  label: "Edit",
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    textStyle: Theme.of(context).primaryTextTheme.bodySmall,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  children: getEditMenuEntries(ref),
                ),
                ContextMenuNested(
                  label: "View",
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    textStyle: Theme.of(context).primaryTextTheme.bodySmall,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  children: getViewMenuEntries(ref),
                ),
                ContextMenuNested(
                  label: "Preferences",
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    textStyle: Theme.of(context).primaryTextTheme.bodySmall,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  children: getPreferencesMenuEntries(ref),
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
            state.fileInfo == null || (state.fileInfo != null && state.fileRawContents != null)
                ? const TextEditor()
                : SizedBox.expand(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Could not open file"),
                      if (state.allowMalformedCharacters)
                        const Text("Try changing the file encoding")
                      else
                        const Text("Try reopening the file with malformed characters"),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed:
                            !state.allowMalformedCharacters
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
