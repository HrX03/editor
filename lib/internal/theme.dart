import 'dart:io';

import 'package:editor/editor/controller.dart';
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
        background: systemAccent.lightest,
        error: Colors.red,
        onPrimary: systemAccent.darkest,
        onSecondary: systemAccent.darkest,
        onBackground: systemAccent.darkest,
        onSurface: systemAccent.darkest,
        onError: Colors.white,
        shadow: Colors.transparent,
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
    extensions: [
      HighlightThemeExtension(editorTheme: editorTheme),
    ],
    cardColor: colorScheme.surface,
    scaffoldBackgroundColor: colorScheme.background,
    brightness: colorScheme.brightness,
  );
}

const scrollbarThemeData = ScrollbarThemeData(
  thickness: MaterialStatePropertyAll(12),
  mainAxisMargin: 0,
  crossAxisMargin: 0,
  radius: Radius.zero,
);
