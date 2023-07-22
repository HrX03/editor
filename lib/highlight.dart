import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart' show Node, highlight;

typedef EditorTheme = Map<String, TextStyle>;

List<TextSpan> _convert(List<Node> nodes, Map<String, TextStyle> theme) {
  final List<TextSpan> spans = [];
  var currentSpans = spans;
  final List<List<TextSpan>> stack = [];

  void traverse(Node node) {
    if (node.value != null) {
      currentSpans.add(
        node.className == null
            ? TextSpan(text: node.value)
            : TextSpan(text: node.value, style: theme[node.className!]),
      );
    } else if (node.children != null) {
      final List<TextSpan> tmp = [];
      currentSpans.add(TextSpan(children: tmp, style: theme[node.className!]));
      stack.add(currentSpans);
      currentSpans = tmp;

      for (final n in node.children!) {
        traverse(n);
        if (n == node.children!.last) {
          currentSpans = stack.isEmpty ? spans : stack.removeLast();
        }
      }
    }
  }

  for (final node in nodes) {
    traverse(node);
  }

  return spans;
}

class EditorTextEditingController extends TextEditingController {
  EditorTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_language == null) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    return TextSpan(
      style: style,
      children: _convert(
        highlight.parse(text, language: _language).nodes!,
        Theme.of(context).extension<HighlightThemeExtension>()!.editorTheme,
      ),
    );
  }

  String? _language;
  String? get language => _language;
  set language(String? newLanguage) {
    _language = newLanguage;
    notifyListeners();
  }
}

class HighlightThemeExtension extends ThemeExtension<HighlightThemeExtension> {
  final EditorTheme editorTheme;

  const HighlightThemeExtension({
    this.editorTheme = const {},
  });

  @override
  HighlightThemeExtension copyWith({EditorTheme? editorTheme}) {
    return HighlightThemeExtension(
      editorTheme: editorTheme ?? this.editorTheme,
    );
  }

  @override
  HighlightThemeExtension lerp(HighlightThemeExtension? other, double t) {
    if (other == null) return this;

    final totalKeys = {
      ...editorTheme.keys,
      ...other.editorTheme.keys,
    };

    final result = {
      for (final key in totalKeys)
        key: TextStyle.lerp(
          editorTheme.get(key, other.editorTheme),
          other.editorTheme.get(key, editorTheme),
          t,
        )!,
    };

    return HighlightThemeExtension(editorTheme: result);
  }
}

extension on EditorTheme {
  TextStyle? get(String key, EditorTheme other) {
    return this[key] ?? other[key];
  }
}
