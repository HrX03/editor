import 'package:collection/collection.dart';
import 'package:editor/editor/controller.dart';
import 'package:editor/editor/intents.dart';
import 'package:editor/internal/value.dart';
import 'package:flutter/material.dart';

final _spaceRegex = RegExp(r"^[\h]+$");
final _anySpaceRegex = RegExp(r"^[\s]+$");
final _anyNonSpaceRegex = RegExp(r"\S");
final _charRegex = RegExp("[A-Za-zÀ-ÖØ-öø-ÿ0-9]");
final _charWithSpaceRegex = RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿ0-9\s]");

CharacterPair? _checkIfPairIsValid(
  String input, [
  bool checkForOpening = true,
]) {
  if (checkForOpening) {
    int spaceAmount = 0;
    while (spaceAmount < input.length) {
      final char = input[input.length - (spaceAmount + 1)];
      final opening =
          handledCharacterPairs.firstWhereOrNull((e) => e.opening == char);
      if (opening != null) return opening;
      if (_anyNonSpaceRegex.hasMatch(char)) return null;
      spaceAmount++;
    }
    return null;
  } else {
    int spaceAmount = 0;
    while (spaceAmount < input.length) {
      final char = input[spaceAmount];
      final closing =
          handledCharacterPairs.firstWhereOrNull((e) => e.closing == char);
      if (closing != null) return closing;
      if (_anyNonSpaceRegex.hasMatch(char)) return null;
      spaceAmount++;
    }
    return null;
  }
}

CharacterPair? _checkIfInsidePair(String before, String after) {
  final opening = _checkIfPairIsValid(before);
  final closing = _checkIfPairIsValid(after, false);

  if (opening == null || closing == null || opening != closing) return null;

  return opening;
}

typedef EditorValueGetter = EditorTextEditingValue Function();
typedef EditorMetadataUpdater = void Function(EditorMetadata metadata);

abstract class EditorAction<T extends Intent> extends ContextAction<T> {
  final EditorValueGetter getEditorValue;
  final EditorMetadataUpdater updateEditorMetadata;

  EditorAction(
    this.getEditorValue,
    this.updateEditorMetadata,
  );
}

class EditorDeleteCharacterAction extends EditorAction<DeleteCharacterIntent> {
  EditorDeleteCharacterAction(super.getEditorValue, super.updateEditorMetadata);

  @override
  Object? invoke(DeleteCharacterIntent intent, [BuildContext? context]) {
    final value = getEditorValue();
    final tabChar = value.tabCharacter;

    if (!value.selection.isCollapsed || intent.forward) {
      return callingAction?.invoke(intent);
    }

    final TextRange replacingRange;
    int pairChainCount = 0;

    final before = value.selection.textBefore(value.text);

    if (before.isEmpty) return callingAction?.invoke(intent);

    final beforeLines = before.split("\n");

    bool isValid = true;
    int spaceAmount = 0;
    while (spaceAmount < beforeLines.last.length) {
      final currChar = beforeLines.last.characters.elementAt(spaceAmount);
      if (!currChar.contains(" ") && !currChar.contains("\t")) {
        isValid = false;
        break;
      }

      spaceAmount++;
    }

    if (isValid && spaceAmount > 0) {
      final mod = spaceAmount % tabChar.length;
      final backAmount = mod != 0 ? mod : tabChar.length;

      replacingRange =
          TextRange(start: before.length - backAmount, end: before.length);
    } else if (value.pairChainCount > 0) {
      replacingRange =
          TextRange(start: before.length - 1, end: before.length + 1);
      pairChainCount = value.pairChainCount - 1;
    } else {
      replacingRange = TextRange(start: before.length - 1, end: before.length);
    }

    Actions.invoke(
      context!,
      ReplaceTextIntent(
        value.value,
        '',
        replacingRange,
        SelectionChangedCause.keyboard,
      ),
    );
    updateEditorMetadata(
      value.metadata.copyWith(pairChainCount: Value(pairChainCount)),
    );
    return null;
  }

  @override
  bool get isActionEnabled => callingAction?.isActionEnabled ?? false;

  @override
  bool consumesKey(DeleteCharacterIntent intent) =>
      callingAction?.consumesKey(intent) ?? false;
}

class EditorIndentationAction extends EditorAction<IndentationIntent> {
  EditorIndentationAction(
    super.getEditorValue,
    super.updateEditorMetadata,
  );

  @override
  void invoke(IndentationIntent intent, [BuildContext? context]) {
    final value = getEditorValue();
    final tabChar = value.tabCharacter;

    final String insertedText;
    final TextRange replacingRange;
    final TextSelection selection;

    final before = value.selection.textBefore(value.text);
    final inside = value.selection.textInside(value.text);

    final cumulative = [before, inside].join();
    final lines = cumulative.split('\n');

    if (lines.last == inside && !value.selection.isCollapsed) {
      insertedText = tabChar;
      replacingRange = TextRange.collapsed(before.length);
      selection = TextSelection(
        baseOffset: before.length,
        extentOffset: cumulative.length + tabChar.length,
      );
    } else if (inside.contains('\n')) {
      final insideLines = inside.split('\n');
      final appliedLines = <String>[];

      for (final line in insideLines) {
        if (line.isEmpty) {
          appliedLines.add(line);
          continue;
        }
        appliedLines.add('$tabChar$line');
      }
      final result = appliedLines.join('\n');

      insertedText = result;
      replacingRange =
          TextRange(start: before.length, end: inside.length + before.length);
      selection = TextSelection(
        baseOffset: before.length,
        extentOffset: before.length + result.length,
      );
    } else {
      insertedText = tabChar;
      replacingRange = TextRange.collapsed(before.length);
      selection =
          TextSelection.collapsed(offset: before.length + tabChar.length);
    }

    Actions.invoke(
      context!,
      ReplaceTextIntent(
        value.value,
        insertedText,
        replacingRange,
        SelectionChangedCause.keyboard,
      ),
    );

    final updatedValue = getEditorValue();
    Actions.invoke(
      context,
      UpdateSelectionIntent(
        updatedValue.value,
        selection,
        SelectionChangedCause.keyboard,
      ),
    );
  }
}

class EditorNewlineIntent extends EditorAction<NewlineIntent> {
  EditorNewlineIntent(
    super.getEditorValue,
    super.updateEditorMetadata,
  );

  @override
  Object? invoke(NewlineIntent intent, [BuildContext? context]) {
    final value = getEditorValue();
    final tabChar = value.tabCharacter;

    final before = value.selection.textBefore(value.text);
    final after = value.selection.textAfter(value.text);

    final beforeLines = before.split("\n");

    int spaceAmount = 0;
    while (spaceAmount < beforeLines.last.length) {
      final currChar = beforeLines.last.characters.elementAt(spaceAmount);
      if (!currChar.contains(" ") && !currChar.contains("\t")) break;
      spaceAmount++;
    }

    final defaultIntent = ReplaceTextIntent(
      value.value,
      ['\n', ' ' * spaceAmount].join(),
      value.selection,
      SelectionChangedCause.keyboard,
    );

    if (before.isEmpty || after.isEmpty) {
      return Actions.invoke(context!, defaultIntent);
    }

    final pair = _checkIfInsidePair(before, after);

    if (pair == null) {
      return Actions.invoke(context!, defaultIntent);
    }

    if (!pair.hasSpecialNewlineBehaviour) {
      return Actions.invoke(context!, defaultIntent);
    }

    Actions.invoke(
      context!,
      ReplaceTextIntent(
        value.value,
        [
          '\n',
          ' ' * (spaceAmount + tabChar.length),
          '\n',
          ' ' * spaceAmount,
        ].join(),
        value.selection,
        SelectionChangedCause.keyboard,
      ),
    );

    final updatedValue = getEditorValue();
    return Actions.invoke(
      context,
      UpdateSelectionIntent(
        updatedValue.value,
        TextSelection.collapsed(
          offset: before.length + 1 + spaceAmount + tabChar.length,
        ),
        SelectionChangedCause.keyboard,
      ),
    );
  }
}

class EditorPairInsertionAction extends EditorAction<PairInsertionIntent> {
  EditorPairInsertionAction(
    super.getEditorValue,
    super.updateEditorMetadata,
  );

  @override
  Object? invoke(PairInsertionIntent intent, [BuildContext? context]) {
    final value = getEditorValue();

    final CharacterPair(
      :opening,
      :closing,
      :enableCollapsedPair,
      :avoidLettersAndDigits,
    ) = intent.pair;

    final before = value.selection.textBefore(value.text);
    final inside = value.selection.textInside(value.text);
    final after = value.selection.textAfter(value.text);

    if (avoidLettersAndDigits && value.selection.isCollapsed) {
      final lChar = before.characters.isNotEmpty ? before.characters.last : "!";
      final rChar = after.characters.isNotEmpty ? after.characters.first : "!";

      if (_charRegex.hasMatch(lChar) || _charRegex.hasMatch(rChar)) {
        return Actions.invoke(
          context!,
          ReplaceTextIntent(
            value.value,
            opening,
            TextRange.collapsed(before.length + opening.length),
            SelectionChangedCause.keyboard,
          ),
        );
      }
    } else if (value.selection.isCollapsed) {
      final lChar = before.characters.isNotEmpty ? before.characters.last : "!";
      final rChar = after.characters.isNotEmpty ? after.characters.first : "!";

      final surroundedByOnlySpace =
          _spaceRegex.hasMatch(lChar) && _spaceRegex.hasMatch(rChar);

      if (_charWithSpaceRegex.hasMatch(lChar) &&
          _charRegex.hasMatch(rChar) &&
          !surroundedByOnlySpace) {
        return Actions.invoke(
          context!,
          ReplaceTextIntent(
            value.value,
            opening,
            TextRange.collapsed(before.length + opening.length),
            SelectionChangedCause.keyboard,
          ),
        );
      }
    }

    final TextSelection? selection;
    final String insertedText;
    final TextRange replacingRange;
    int pairChainCount = value.pairChainCount + 1;

    if (value.selection.isCollapsed && enableCollapsedPair) {
      insertedText = [opening, closing].join();
      replacingRange = TextRange.collapsed(before.length);
      selection =
          TextSelection.collapsed(offset: before.length + opening.length);
    } else if (_anySpaceRegex.hasMatch(inside)) {
      insertedText = opening;
      replacingRange = TextRange.collapsed(before.length);
      selection = null;
      pairChainCount = 0;
    } else if (!value.selection.isCollapsed) {
      insertedText = [opening, inside, closing].join();
      replacingRange =
          TextRange(start: before.length, end: before.length + inside.length);
      selection = TextSelection(
        baseOffset: before.length + opening.length,
        extentOffset: before.length + opening.length + inside.length,
      );
    } else {
      insertedText = opening;
      replacingRange = TextRange.collapsed(before.length);
      selection = null;
      pairChainCount = 0;
    }

    Actions.invoke(
      context!,
      ReplaceTextIntent(
        value.value,
        insertedText,
        replacingRange,
        SelectionChangedCause.keyboard,
      ),
    );

    if (selection != null) {
      final updatedValue = getEditorValue();
      Actions.invoke(
        context,
        UpdateSelectionIntent(
          updatedValue.value,
          selection,
          SelectionChangedCause.keyboard,
        ),
      );
    }

    updateEditorMetadata(
      value.metadata.copyWith(pairChainCount: Value(pairChainCount)),
    );

    return null;
  }
}
