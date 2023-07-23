import 'dart:io';

import 'package:editor/controller.dart';
import 'package:editor/editor.dart';
import 'package:editor/environment.dart';
import 'package:editor/toolbar.dart';
import 'package:editor/window.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_highlighter/themes/atom-one-dark.dart';
import 'package:flutter_highlighter/themes/atom-one-light.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';

bool get _enableWindowEffects => Platform.isWindows;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemTheme.accentColor.load();

  if (_enableWindowEffects) {
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
    if (_enableWindowEffects) await Window.setEffect(effect: WindowEffect.mica);
    await windowManager.show();
    await windowManager.focus();
  });

  final file = args.isNotEmpty ? File(args.first) : null;

  runApp(MainApp(file: file));
}

ColorScheme _buildSchemeForSystemAccent(
  SystemAccentColor systemAccent,
  Brightness brightness, {
  bool vividColors = false,
}) {
  if (!vividColors) {
    return ColorScheme.fromSeed(
      seedColor: systemAccent.accent,
      brightness: brightness,
    );
  }

  return switch (brightness) {
    Brightness.light => ColorScheme(
        primary: systemAccent.accent,
        secondary: systemAccent.light,
        surface: systemAccent.lighter,
        background: systemAccent.lightest,
        error: Colors.red,
        onPrimary: systemAccent.darkest,
        onSecondary: systemAccent.darkest,
        onBackground: systemAccent.darkest,
        onSurface: systemAccent.darkest,
        onError: Colors.white,
        brightness: Brightness.light,
      ),
    Brightness.dark => ColorScheme(
        primary: systemAccent.accent,
        secondary: systemAccent.dark,
        surface: systemAccent.darker,
        background: systemAccent.darkest,
        error: Colors.red,
        onPrimary: systemAccent.lightest,
        onSecondary: systemAccent.lightest,
        onBackground: systemAccent.lightest,
        onSurface: systemAccent.lightest,
        onError: Colors.white,
        brightness: Brightness.dark,
      ),
  };
}

const scrollbarThemeData = ScrollbarThemeData(
  thickness: MaterialStatePropertyAll(12),
  mainAxisMargin: 0,
  crossAxisMargin: 0,
  radius: Radius.zero,
);

class MainApp extends StatelessWidget {
  final File? file;

  const MainApp({this.file, super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SystemAccentColor>(
      stream: SystemTheme.onChange,
      builder: (context, snapshot) {
        final systemTheme = snapshot.data ?? SystemTheme.accentColor;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(useMaterial3: true).copyWith(
            colorScheme:
                _buildSchemeForSystemAccent(systemTheme, Brightness.light),
            scrollbarTheme: scrollbarThemeData,
            extensions: const [
              HighlightThemeExtension(editorTheme: atomOneLightTheme),
            ],
          ),
          darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
            colorScheme:
                _buildSchemeForSystemAccent(systemTheme, Brightness.dark),
            scrollbarTheme: scrollbarThemeData,
            extensions: const [
              HighlightThemeExtension(editorTheme: atomOneDarkTheme),
            ],
          ),
          home: _EditorApp(initialFile: file),
        );
      },
    );
  }
}

class _EditorApp extends StatefulWidget {
  final File? initialFile;

  const _EditorApp({this.initialFile});

  @override
  State<_EditorApp> createState() => _EditorAppState();
}

class _EditorAppState extends State<_EditorApp> {
  late final environment = EditorEnvironment(file: widget.initialFile);

  @override
  Widget build(BuildContext context) {
    return EditorEnvironmentProvider(
      environment: environment,
      child: WindowEffectSetter(
        effect: WindowEffect.mica,
        theme: Theme.of(context),
        enableEffects: _enableWindowEffects,
        child: Scaffold(
          backgroundColor: _enableWindowEffects
              ? Colors.transparent
              : Theme.of(context).colorScheme.background,
          appBar: WindowBar(
            title: const WindowTitle(),
            menus: [
              SubmenuButton(
                menuChildren: [
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      environment.editorFile,
                      environment.textController,
                    ]),
                    builder: (context, _) => MenuItemButton(
                      onPressed: environment.hasEdits ||
                              environment.editorFile.file != null
                          ? environment.closeFile
                          : null,
                      child: const Text("New"),
                    ),
                  ),
                  MenuItemButton(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles();
                      if (result == null) return;

                      environment.openFile(File(result.files.first.path!));
                    },
                    child: const Text("Open"),
                  ),
                ],
                child: const Text("File"),
              ),
              SubmenuButton(
                menuChildren: [
                  ValueListenableBuilder(
                    valueListenable: environment.enableLineNumberColumnNotifier,
                    builder: (context, value, _) {
                      return MenuItemButton(
                        onPressed: () {
                          environment.enableLineNumberColumn = !value;
                        },
                        trailingIcon: value
                            ? const Icon(Icons.check)
                            : const SizedBox.square(dimension: 24),
                        child: const Text("Line numbers"),
                      );
                    },
                  ),
                  ValueListenableBuilder(
                    valueListenable: environment.enableLineHighlightingNotifier,
                    builder: (context, value, _) {
                      return MenuItemButton(
                        onPressed: () {
                          environment.enableLineHighlighting = !value;
                        },
                        trailingIcon: value
                            ? const Icon(Icons.check)
                            : const SizedBox.square(dimension: 24),
                        child: const Text("Line highlight"),
                      );
                    },
                  ),
                ],
                child: const Text("View"),
              ),
            ],
          ),
          body: Theme(
            data: Theme.of(context).copyWith(
              textTheme: GoogleFonts.firaCodeTextTheme(),
            ),
            child: const TextEditor(),
          ),
          bottomNavigationBar: const SizedBox(
            height: 24,
            child: EditorToolbar(),
          ),
        ),
      ),
    );
  }
}
