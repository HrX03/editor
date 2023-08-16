import 'package:editor/internal/value.dart';
import 'package:flutter/material.dart';
import 'package:highlighting/highlighting.dart' show Node, highlight;
// ignore: implementation_imports
import 'package:highlighting/src/language.dart';

typedef EditorTheme = Map<String, TextStyle>;

class CharacterPair {
  final String opening;
  final String closing;
  final bool enableCollapsedPair;
  final bool avoidLettersAndDigits;
  final bool hasSpecialNewlineBehaviour;

  const CharacterPair(
    this.opening,
    this.closing, {
    this.enableCollapsedPair = true,
    this.avoidLettersAndDigits = false,
    this.hasSpecialNewlineBehaviour = false,
  });
}

const handledCharacterPairs = <CharacterPair>[
  CharacterPair('(', ')', hasSpecialNewlineBehaviour: true),
  CharacterPair('[', ']', hasSpecialNewlineBehaviour: true),
  CharacterPair('{', '}', hasSpecialNewlineBehaviour: true),
  CharacterPair('<', '>', enableCollapsedPair: false),
  CharacterPair("'", "'", avoidLettersAndDigits: true),
  CharacterPair('"', '"', avoidLettersAndDigits: true),
  CharacterPair('`', '`', avoidLettersAndDigits: true),
];

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
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (language == null) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    return TextSpan(
      style: style,
      children: _convert(
        highlight.parse(text, languageId: language!.id).nodes!,
        Theme.of(context).extension<HighlightThemeExtension>()!.editorTheme,
      ),
    );
  }

  @override
  set value(TextEditingValue newValue) {
    if (value.selection != newValue.selection) {
      // we moved, have to reset pair info
      pairChainCount = 0;
    }
    super.value = newValue;
  }

  EditorMetadata _metadata =
      (language: null, pairChainCount: 0, tabCharacter: '  ');
  EditorMetadata get metadata => _metadata;
  set metadata(EditorMetadata newMetadata) {
    if (_metadata.language != newMetadata.language) {
      language = newMetadata.language;
    }

    if (_metadata.pairChainCount != newMetadata.pairChainCount) {
      pairChainCount = newMetadata.pairChainCount;
    }
  }

  int get pairChainCount => _metadata.pairChainCount;
  set pairChainCount(int newValue) {
    _metadata = _metadata.copyWith(pairChainCount: Value(newValue));
  }

  Language? get language => _metadata.language;
  set language(Language? newLanguage) {
    _metadata = _metadata.copyWith(language: Value(newLanguage));
    notifyListeners();
  }

  EditorTextEditingValue get annotatedValue =>
      (value: value, metadata: metadata);
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

typedef EditorTextEditingValue = ({
  TextEditingValue value,
  EditorMetadata metadata,
});

extension EnhancedUtils on EditorTextEditingValue {
  TextSelection get selection => value.selection;
  String get text => value.text;
  Language? get language => metadata.language;
  int get pairChainCount => metadata.pairChainCount;
  String get tabCharacter => metadata.tabCharacter;
}

typedef EditorMetadata = ({
  Language? language,
  int pairChainCount,
  String tabCharacter,
});

extension EditorMetadataCopyWith on EditorMetadata {
  EditorMetadata copyWith({
    Value<Language?>? language,
    Value<int>? pairChainCount,
    Value<String>? tabCharacter,
  }) {
    return (
      language: Value.handleValue(language, null, this.language),
      pairChainCount:
          Value.handleValue(pairChainCount, 0) ?? this.pairChainCount,
      tabCharacter: Value.handleValue(tabCharacter, '  ') ?? this.tabCharacter,
    );
  }
}
