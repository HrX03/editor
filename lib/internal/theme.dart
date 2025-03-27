import 'dart:io';

import 'package:flutter/material.dart';
import 'package:system_theme/system_theme.dart';

bool get platformSupportsWindowEffects => Platform.isWindows;

ColorScheme buildSchemeForSystemAccent(
  SystemAccentColor systemAccent,
  Brightness brightness, {
  bool vividColors = false,
}) {
  if (!vividColors) {
    return ColorScheme.fromSeed(
      seedColor: systemAccent.accent,
      shadow: Colors.transparent,
      brightness: brightness,
    );
  }

  return switch (brightness) {
    Brightness.light => ColorScheme(
      primary: systemAccent.accent,
      secondary: systemAccent.light,
      surface: systemAccent.lighter,
      error: Colors.red,
      onPrimary: systemAccent.darkest,
      onSecondary: systemAccent.darkest,
      onSurface: systemAccent.darkest,
      onError: Colors.white,
      shadow: Colors.transparent,
      brightness: Brightness.light,
    ),
    Brightness.dark => ColorScheme(
      primary: systemAccent.accent,
      secondary: systemAccent.dark,
      surface: systemAccent.darker,
      error: Colors.red,
      onPrimary: systemAccent.lightest,
      onSecondary: systemAccent.lightest,
      onSurface: systemAccent.lightest,
      onError: Colors.white,
      shadow: Colors.transparent,
      brightness: Brightness.dark,
    ),
  };
}

ThemeData buildTheme({
  required ColorScheme colorScheme,
  required Map<String, TextStyle> editorTheme,
}) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    shadowColor: Colors.transparent,
    scrollbarTheme: scrollbarThemeData,
    extensions: [HighlightThemeExtension(editorTheme: editorTheme)],
    popupMenuTheme: const PopupMenuThemeData(menuPadding: EdgeInsets.symmetric(vertical: 4)),
    cardColor: colorScheme.surface,
    scaffoldBackgroundColor: colorScheme.surface,
    brightness: colorScheme.brightness,
  );
}

const scrollbarThemeData = ScrollbarThemeData(
  thickness: WidgetStatePropertyAll(12),
  mainAxisMargin: 0,
  crossAxisMargin: 0,
  radius: Radius.zero,
);

MenuStyle getMenuStyle() =>
    const MenuStyle(padding: WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 12)));

ButtonStyle getMenuItemStyle(ThemeData theme) => TextButton.styleFrom(
  minimumSize: const Size(220, 36),
  textStyle: theme.primaryTextTheme.bodySmall,
  padding: const EdgeInsets.symmetric(horizontal: 16),
);

ButtonStyle getNestedMenuItemStyle(ThemeData theme) => TextButton.styleFrom(
  minimumSize: const Size(0, 36),
  textStyle: theme.primaryTextTheme.bodySmall,
  padding: const EdgeInsets.only(left: 16, right: 8),
);

class HighlightThemeExtension extends ThemeExtension<HighlightThemeExtension> {
  final EditorTheme editorTheme;

  const HighlightThemeExtension({this.editorTheme = const {}});

  @override
  HighlightThemeExtension copyWith({EditorTheme? editorTheme}) {
    return HighlightThemeExtension(editorTheme: editorTheme ?? this.editorTheme);
  }

  @override
  HighlightThemeExtension lerp(HighlightThemeExtension? other, double t) {
    if (other == null) return this;

    final totalKeys = {...editorTheme.keys, ...other.editorTheme.keys};

    final result = {
      for (final key in totalKeys)
        key:
            TextStyle.lerp(
              editorTheme.get(key, other.editorTheme),
              other.editorTheme.get(key, editorTheme),
              t,
            )!,
    };

    return HighlightThemeExtension(editorTheme: result);
  }
}

typedef EditorTheme = Map<String, TextStyle>;

extension on EditorTheme {
  TextStyle? get(String key, EditorTheme other) {
    return this[key] ?? other[key];
  }
}
