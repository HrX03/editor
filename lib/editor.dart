import 'dart:math';
import 'dart:ui' as ui;

import 'package:editor/double_scrollbars.dart';
import 'package:editor/environment.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

final _indentationRegex = RegExp(r"^[\s]*(?![~\s])");
final _spaceRegex = RegExp(r"^[ ]+$");
final _charRegex = RegExp("[A-Za-zÀ-ÖØ-öø-ÿ0-9]");
final _charWithSpaceRegex = RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿ0-9\s]");

class TextEditor extends StatefulWidget {
  const TextEditor({super.key});

  @override
  State<TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<TextEditor>
    implements TextSelectionGestureDetectorBuilderDelegate {
  final focusNode = FocusNode();
  final key = GlobalKey<EditableTextState>();
  late final gestureBuilder =
      TextSelectionGestureDetectorBuilder(delegate: this);
  final verticalScrollController = ScrollController();
  final horizontalScrollController = ScrollController();

  @override
  GlobalKey<EditableTextState> get editableTextKey => key;

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => true;

  @override
  Widget build(BuildContext context) {
    final environment = EditorEnvironment.of(context);
    final controller = environment.textController;

    final style = GoogleFonts.firaCode(
      fontSize: 16,
      height: 1.3,
      color: Theme.of(context).colorScheme.onSurface,
    );

    return DoubleScrollbars(
      verticalController: verticalScrollController,
      horizontalController: horizontalScrollController,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ScrollProxy(
          direction: Axis.vertical,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
            controller: verticalScrollController,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _LineHighlightLayer(
                  controller: controller,
                  style: style,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LineNumberColumn(
                        controller: controller,
                        style: style,
                        scrollController: verticalScrollController,
                      ),
                      Expanded(
                        child: ScrollProxy(
                          direction: Axis.horizontal,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            controller: horizontalScrollController,
                            child: _EditorClipper(
                              horizontalController: horizontalScrollController,
                              verticalController: verticalScrollController,
                              child: _EditorView(
                                controller: controller,
                                undoController: environment.undoController,
                                style: style,
                                editableKey: key,
                                hintText: "Start typing to edit",
                                selectionDelegate: this,
                                focusNode: focusNode,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorView extends StatelessWidget {
  final TextEditingController controller;
  final UndoHistoryController undoController;
  final TextStyle style;
  final GlobalKey<EditableTextState> editableKey;
  final String hintText;
  final FocusNode focusNode;
  final TextSelectionGestureDetectorBuilderDelegate selectionDelegate;

  const _EditorView({
    required this.controller,
    required this.undoController,
    required this.style,
    required this.editableKey,
    required this.hintText,
    required this.focusNode,
    required this.selectionDelegate,
  });

  @override
  Widget build(BuildContext context) {
    final builder =
        TextSelectionGestureDetectorBuilder(delegate: selectionDelegate);

    return UnconstrainedBox(
      alignment: Alignment.topLeft,
      child: IntrinsicWidth(
        child: _EditorDecorator(
          controller: controller,
          focusNode: focusNode,
          style: style,
          hintText: hintText,
          child: builder.buildGestureDetector(
            behavior: HitTestBehavior.translucent,
            child: RepaintBoundary(
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyUpEvent) return KeyEventResult.ignored;

                  switch (event.logicalKey) {
                    case LogicalKeyboardKey.tab:
                      controller.value = _insertIndendations(controller.value);
                      return KeyEventResult.handled;
                    case LogicalKeyboardKey.enter:
                      controller.value = _insertNewline(controller.value);
                      return KeyEventResult.handled;
                  }

                  switch (event.character) {
                    case '(':
                      controller.value = _insertCharPair(
                        controller.value,
                        ('(', ')'),
                      );
                      return KeyEventResult.handled;
                    case '[':
                      controller.value = _insertCharPair(
                        controller.value,
                        ('[', ']'),
                      );
                      return KeyEventResult.handled;
                    case '{':
                      controller.value = _insertCharPair(
                        controller.value,
                        ('{', '}'),
                      );
                      return KeyEventResult.handled;
                    case '<':
                      controller.value = _insertCharPair(
                        controller.value,
                        ('<', '>'),
                        enableCollapsedPair: false,
                      );
                      return KeyEventResult.handled;
                    case "'":
                      controller.value = _insertCharPair(
                        controller.value,
                        ("'", "'"),
                        avoidLettersAndDigits: true,
                      );
                      return KeyEventResult.handled;
                    case '"':
                      controller.value = _insertCharPair(
                        controller.value,
                        ('"', '"'),
                        avoidLettersAndDigits: true,
                      );
                      return KeyEventResult.handled;
                  }

                  return KeyEventResult.ignored;
                },
                child: EditableText(
                  key: editableKey,
                  scrollPadding: EdgeInsets.zero,
                  controller: controller,
                  focusNode: focusNode,
                  undoController: undoController,
                  style: Theme.of(context).textTheme.bodyLarge!.merge(style),
                  maxLines: null,
                  cursorColor: Theme.of(context).colorScheme.primary,
                  backgroundCursorColor: Colors.transparent,
                  selectionColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  rendererIgnoresPointer: true,
                  selectionControls: desktopTextSelectionControls,
                  contextMenuBuilder: (context, editableTextState) {
                    return AdaptiveTextSelectionToolbar.editableText(
                      editableTextState: editableTextState,
                    );
                  },
                  cursorOpacityAnimates: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(
                      '\r\n',
                      replacementString: '\n',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

TextEditingValue _insertIndendations(
  TextEditingValue value, [
  String tabChar = '  ',
]) {
  final String text;
  final TextSelection selection;

  final before = value.selection.textBefore(value.text);
  final inside = value.selection.textInside(value.text);
  final after = value.selection.textAfter(value.text);

  final cumulative = [before, inside].join();
  final lines = cumulative.split('\n');

  if (lines.last == inside && !value.selection.isCollapsed) {
    text = [before, tabChar, inside, after].join();
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

    text = [before, result, after].join();
    selection = TextSelection(
      baseOffset: before.length,
      extentOffset: before.length + result.length,
    );
  } else {
    text = [before, tabChar, after].join();
    selection = TextSelection.collapsed(offset: before.length + tabChar.length);
  }

  return TextEditingValue(text: text, selection: selection);
}

TextEditingValue _insertNewline(TextEditingValue value) {
  final before = value.selection.textBefore(value.text);
  final after = value.selection.textAfter(value.text);

  final beforeLines = before.split("\n");
  final match = _indentationRegex.firstMatch(beforeLines.last);
  final group = match?.group(0);

  final spaceAmount = group != null ? group.length : 0;

  return TextEditingValue(
    text: [before, '\n', ' ' * spaceAmount, after].join(),
    selection: TextSelection.collapsed(offset: before.length + 1 + spaceAmount),
  );
}

TextEditingValue _insertCharPair(
  TextEditingValue value,
  (String, String) pair, {
  bool enableCollapsedPair = true,
  bool avoidLettersAndDigits = false,
}) {
  final String text;
  final TextSelection selection;

  final (opening, closing) = pair;

  final before = value.selection.textBefore(value.text);
  final inside = value.selection.textInside(value.text);
  final after = value.selection.textAfter(value.text);

  if (avoidLettersAndDigits && value.selection.isCollapsed) {
    final lChar = before.characters.isNotEmpty ? before.characters.last : "!";
    final rChar = after.characters.isNotEmpty ? after.characters.first : "!";

    if (_charRegex.hasMatch(lChar) || _charRegex.hasMatch(rChar)) {
      return TextEditingValue(
        text: [before, opening, after].join(),
        selection: TextSelection.collapsed(
          offset: before.length + opening.length,
        ),
      );
    }
  } else if (value.selection.isCollapsed) {
    final lChar = before.characters.isNotEmpty ? before.characters.last : "!";
    final rChar = after.characters.isNotEmpty ? after.characters.first : "!";

    final surroundedByOnlySpace =
        _spaceRegex.hasMatch(lChar) && _spaceRegex.hasMatch(rChar);

    if (_charWithSpaceRegex.hasMatch(lChar) &&
        _charWithSpaceRegex.hasMatch(rChar) &&
        !surroundedByOnlySpace) {
      return TextEditingValue(
        text: [before, opening, after].join(),
        selection: TextSelection.collapsed(
          offset: before.length + opening.length,
        ),
      );
    }
  }

  if (value.selection.isCollapsed && enableCollapsedPair) {
    text = [before, opening, closing, after].join();
    selection = TextSelection.collapsed(offset: before.length + opening.length);
  } else if (_spaceRegex.hasMatch(inside)) {
    text = [before, opening, after].join();
    selection = TextSelection.collapsed(offset: before.length + opening.length);
  } else if (!value.selection.isCollapsed) {
    text = [before, opening, inside, closing, after].join();
    selection = TextSelection(
      baseOffset: before.length + opening.length,
      extentOffset: before.length + opening.length + inside.length,
    );
  } else {
    text = [before, opening, after].join();
    selection = TextSelection.collapsed(
      offset: before.length + opening.length,
    );
  }

  return TextEditingValue(text: text, selection: selection);
}

class _EditorClipper extends StatelessWidget {
  final ScrollController verticalController;
  final ScrollController horizontalController;
  final Widget child;

  const _EditorClipper({
    required this.verticalController,
    required this.horizontalController,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      clipper: _EditorRectClipper(
        horizontalController: horizontalController,
        verticalController: verticalController,
      ),
      child: child,
    );
  }
}

class _EditorRectClipper extends CustomClipper<Rect> {
  final ScrollController verticalController;
  final ScrollController horizontalController;

  _EditorRectClipper({
    required this.verticalController,
    required this.horizontalController,
  }) : super(
          reclip: Listenable.merge([verticalController, horizontalController]),
        );

  @override
  ui.Rect getClip(ui.Size size) {
    if (!horizontalController.position.hasContentDimensions ||
        verticalController.position.hasContentDimensions) {
      return Rect.largest;
    }

    return Rect.fromLTWH(
      horizontalController.position.extentBefore,
      verticalController.position.extentBefore,
      horizontalController.position.extentInside,
      verticalController.position.extentInside,
    );
  }

  @override
  bool shouldReclip(covariant CustomClipper<ui.Rect> oldClipper) {
    return true;
  }
}

class _LineNumberColumn extends StatelessWidget {
  static const EdgeInsets padding = EdgeInsets.symmetric(horizontal: 16);

  final TextEditingController controller;
  final ScrollController scrollController;
  final TextStyle style;

  const _LineNumberColumn({
    required this.controller,
    required this.scrollController,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, scrollController]),
      builder: (context, _) {
        final lines = controller.text.split('\n');
        if (lines.isEmpty) lines.add('0');
        final span =
            controller.buildTextSpan(context: context, withComposing: false);
        final baseStyle = span.style ?? style;
        final minWidthParagraph = _buildParagraphFor(
          '0' * max(3, lines.length.toString().length),
          baseStyle,
          double.infinity,
        );
        final colWidth = minWidthParagraph.longestLine.ceilToDouble() + 1.0;

        final textPosition =
            controller.selection.start > controller.selection.end
                ? controller.selection.base
                : controller.selection.extent;
        final highlightedLine = textPosition.offset > 0 &&
                textPosition.offset <= controller.text.length
            ? controller.text
                .substring(0, textPosition.offset)
                .split("\n")
                .length
            : 1;
        final position = scrollController.position;

        return Padding(
          padding: padding,
          child: CustomPaint(
            painter: _LineColumnPainter(
              lineCount: lines.length,
              visiblePortion:
                  position.hasContentDimensions ? position.extentInside : 0.0,
              visiblePortionOffset:
                  position.hasContentDimensions ? position.extentBefore : 0.0,
              lineHeight: minWidthParagraph.height,
              style: style.copyWith(
                color: style.color!.withOpacity(0.2),
              ),
              highlightedLine: highlightedLine,
              highlightedStyle: style.copyWith(
                color: style.color!.withOpacity(0.8),
              ),
            ),
            child: SizedBox(
              width: colWidth,
              height: lines.length * minWidthParagraph.height,
            ),
          ),
        );
      },
    );
  }
}

class _LineColumnPainter extends CustomPainter {
  final double visiblePortion;
  final double visiblePortionOffset;
  final int lineCount;
  final double lineHeight;
  final TextStyle style;
  final int highlightedLine;
  final TextStyle highlightedStyle;

  const _LineColumnPainter({
    required this.visiblePortion,
    required this.visiblePortionOffset,
    required this.lineCount,
    required this.lineHeight,
    required this.style,
    required this.highlightedLine,
    required this.highlightedStyle,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    int start = (visiblePortionOffset / lineHeight).floor();
    int end = ((visiblePortionOffset + visiblePortion) / lineHeight).ceil();

    if (end < lineCount || end > lineCount) end = lineCount;
    if (start > end) start = end - 1;

    for (int i = max(start, 0); i < end; i++) {
      final y = i * lineHeight;
      final paragraph = _buildParagraphFor(
        "${i + 1}",
        (i + 1) == highlightedLine ? highlightedStyle : style,
        size.width,
        buildParagraphStyle: (style) =>
            style.getParagraphStyle(textAlign: TextAlign.end),
      );

      canvas.drawParagraph(paragraph, Offset(0, y));
    }
  }

  @override
  bool shouldRepaint(covariant _LineColumnPainter old) {
    return visiblePortion != old.visiblePortion ||
        visiblePortionOffset != old.visiblePortionOffset ||
        lineCount != old.lineCount ||
        lineHeight != old.lineHeight ||
        style != old.style ||
        highlightedLine != old.highlightedLine ||
        highlightedStyle != old.highlightedStyle;
  }
}

ui.Paragraph _buildParagraphFor(
  String text,
  TextStyle style,
  double width, {
  ui.ParagraphStyle Function(TextStyle style)? buildParagraphStyle,
}) {
  final builder = ui.ParagraphBuilder(
    buildParagraphStyle?.call(style) ?? style.getParagraphStyle(),
  );

  builder.pushStyle(style.getTextStyle());
  builder.addText(text);
  final paragraph = builder.build();
  paragraph.layout(ui.ParagraphConstraints(width: width));

  return paragraph;
}

class _EditorDecorator extends StatelessWidget {
  final String hintText;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final Widget child;

  const _EditorDecorator({
    required this.hintText,
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, focusNode]),
      builder: (context, child) {
        return InputDecorator(
          textAlign: TextAlign.start,
          textAlignVertical: TextAlignVertical.center,
          baseStyle: style,
          decoration: InputDecoration(
            hintText: hintText,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isDense: true,
            isCollapsed: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 4.0),
            fillColor: Colors.transparent,
          ),
          isFocused: focusNode.hasFocus,
          isEmpty: controller.value.text.isEmpty,
          child: child,
        );
      },
      child: child,
    );
  }
}

class _LineHighlightLayer extends StatelessWidget {
  final TextEditingController controller;
  final TextStyle style;
  final Widget child;

  const _LineHighlightLayer({
    required this.controller,
    required this.style,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final sampleParagraph = _buildParagraphFor("0", style, double.infinity);
        final position = controller.selection.start > controller.selection.end
            ? controller.selection.base
            : controller.selection.extent;
        final highlightedLine = position.offset > 0 &&
                position.offset <= controller.text.length
            ? controller.text.substring(0, position.offset).split("\n").length
            : 1;

        return Stack(
          children: [
            if (controller.selection.isCollapsed)
              Positioned(
                top: sampleParagraph.height * (highlightedLine - 1),
                height: sampleParagraph.height,
                left: 0,
                right: 0,
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                ),
              ),
            child!,
          ],
        );
      },
      child: child,
    );
  }
}
