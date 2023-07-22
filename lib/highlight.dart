import 'package:flutter/material.dart';
import 'package:highlighting/highlighting.dart' show Node, highlight;
// ignore: implementation_imports
import 'package:highlighting/src/language.dart';

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
            : TextSpan(text: node.value, style: theme[node.className]),
      );
    } else {
      final List<TextSpan> tmp = [];
      currentSpans.add(TextSpan(children: tmp, style: theme[node.className]));
      stack.add(currentSpans);
      currentSpans = tmp;

      for (final n in node.children) {
        traverse(n);
        if (n == node.children.last) {
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
  EnhancedTextEditingValue get value => super.value is EnhancedTextEditingValue
      ? super.value as EnhancedTextEditingValue
      : EnhancedTextEditingValue.fromValue(super.value);

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
        highlight.parse(text, languageId: _language!.id).nodes!,
        Theme.of(context).extension<HighlightThemeExtension>()!.editorTheme,
      ),
    );
  }

  Language? _language;
  Language? get language => _language;
  set language(Language? newLanguage) {
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

class EnhancedTextEditingValue extends TextEditingValue {
  final int pairChainCount;

  const EnhancedTextEditingValue({
    super.text,
    super.selection,
    super.composing,
    this.pairChainCount = 0,
  });

  factory EnhancedTextEditingValue.fromValue(TextEditingValue value) {
    return EnhancedTextEditingValue(
      text: value.text,
      selection: value.selection,
      composing: value.composing,
    );
  }

  @override
  EnhancedTextEditingValue copyWith({
    String? text,
    TextSelection? selection,
    TextRange? composing,
    int? pairChainCount,
  }) {
    return EnhancedTextEditingValue(
      text: text ?? this.text,
      selection: selection ?? this.selection,
      composing: composing ?? this.composing,
      // special case, we want to erase this flag unless we specify we wanna keep it
      pairChainCount: pairChainCount ?? 0,
    );
  }
}
