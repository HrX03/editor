import 'dart:math';
import 'dart:ui' as ui;

import 'package:editor/editor/actions.dart';
import 'package:editor/editor/controller.dart';
import 'package:editor/editor/intents.dart';
import 'package:editor/internal/environment.dart';
import 'package:editor/internal/preferences.dart';
import 'package:editor/widgets/double_scrollbars.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class TextEditor extends ConsumerStatefulWidget {
  const TextEditor({super.key});

  @override
  ConsumerState<TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends ConsumerState<TextEditor>
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
    final controller = ref.watch(editorControllerProvider);
    final undoController = ref.watch(undoControllerProvider);
    final builder = TextSelectionGestureDetectorBuilder(delegate: this);

    final style = GoogleFonts.firaCode(
      fontSize: 16,
      height: 1.3,
      color: Theme.of(context).colorScheme.onSurface,
    );

    return Consumer(
      builder: (context, ref, child) {
        final enableLineNumberColumn =
            ref.watch(enableLineNumberColumnProvider);
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

        return DoubleScrollbars(
          verticalController: verticalScrollController,
          horizontalController: horizontalScrollController,
          horizontalPadding: enableLineNumberColumn
              ? EdgeInsetsDirectional.only(
                  start: colWidth + _LineNumberColumn.padding.horizontal,
                  end: -colWidth - _LineNumberColumn.padding.horizontal,
                )
              : const EdgeInsetsDirectional.only(start: 16.0, end: -16.0),
          child: ScrollConfiguration(
            behavior: _NoScrollbarScrollBehavior(),
            child: ScrollProxy(
              direction: Axis.vertical,
              child: builder.buildGestureDetector(
                behavior: HitTestBehavior.deferToChild,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
                  controller: verticalScrollController,
                  child: _LineHighlightLayer(
                    controller: controller,
                    style: style,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (enableLineNumberColumn)
                          _LineNumberColumn(
                            controller: controller,
                            focusNode: focusNode,
                            style: style,
                            scrollController: verticalScrollController,
                          ),
                        Expanded(
                          child: Padding(
                            padding: enableLineNumberColumn
                                ? EdgeInsets.zero
                                : const EdgeInsetsDirectional.only(start: 16),
                            child: child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
              undoController: undoController,
              style: style,
              editableKey: key,
              hintText: "Start typing to edit",
              selectionDelegate: this,
              focusNode: focusNode,
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorView extends StatelessWidget {
  final EditorTextEditingController controller;
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
    return UnconstrainedBox(
      alignment: Alignment.topLeft,
      child: IntrinsicWidth(
        child: _EditorDecorator(
          controller: controller,
          focusNode: focusNode,
          style: style,
          hintText: hintText,
          child: RepaintBoundary(
            child: Shortcuts(
              shortcuts: {
                const SingleActivator(LogicalKeyboardKey.tab):
                    const IndentationIntent(),
                const SingleActivator(LogicalKeyboardKey.enter):
                    const NewlineIntent(),
                for (final needsAlt in const <bool>[false, true])
                  for (final pair in handledCharacterPairs)
                    CharacterActivator(
                      pair.opening,
                      alt: needsAlt,
                      control: needsAlt,
                    ): PairInsertionIntent(pair),
              },
              child: Actions(
                actions: {
                  DeleteCharacterIntent:
                      _buildEditorAction(EditorDeleteCharacterAction.new),
                  IndentationIntent:
                      _buildEditorAction(EditorIndentationAction.new),
                  NewlineIntent: _buildEditorAction(EditorNewlineIntent.new),
                  PairInsertionIntent:
                      _buildEditorAction(EditorPairInsertionAction.new),
                },
                child: TextFieldTapRegion(
                  child: EditableText(
                    autofocus: true,
                    scrollBehavior: _NoScrollbarScrollBehavior(),
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
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  T _buildEditorAction<T extends EditorAction>(
    T Function(EditorValueGetter getter, EditorMetadataUpdater updater) action,
  ) {
    return action(
      () => controller.annotatedValue,
      (v) => controller.metadata = v,
    );
  }
}

class _NoScrollbarScrollBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
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

  final EditorTextEditingController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final TextStyle style;

  const _LineNumberColumn({
    required this.controller,
    required this.focusNode,
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

        return _LineColumnGestureDetector(
          controller: controller,
          focusNode: focusNode,
          lineHeight: minWidthParagraph.height,
          child: Padding(
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
          ),
        );
      },
    );
  }
}

class _LineColumnGestureDetector extends StatefulWidget {
  final EditorTextEditingController controller;
  final FocusNode focusNode;
  final double lineHeight;
  final Widget child;

  const _LineColumnGestureDetector({
    required this.controller,
    required this.focusNode,
    required this.lineHeight,
    required this.child,
  });

  @override
  State<_LineColumnGestureDetector> createState() =>
      _LineColumnGestureDetectorState();
}

class _LineColumnGestureDetectorState
    extends State<_LineColumnGestureDetector> {
  int startIndex = -1;

  TextSelection _selectFromIndexes(int start, int end) {
    final lines = widget.controller.text.split("\n");

    final reverseDir = start > end;
    final fixedStart = reverseDir ? end : start;
    final fixedEnd = reverseDir ? start : end;

    final lastLine = fixedEnd == lines.length - 1;

    final base = _getOffsetForIndex(lines, fixedStart);
    final extent = _getOffsetForIndex(lines, fixedEnd) +
        lines[fixedEnd].length +
        (!lastLine ? 1 : 0);

    return TextSelection(
      baseOffset: reverseDir ? extent : base,
      extentOffset: reverseDir ? base : extent,
    );
  }

  int _getOffsetForIndex(List<String> lines, int index) {
    final prev = lines.sublist(0, index);
    return prev.fold(0, (p, e) => p + e.length) + prev.length;
  }

  @override
  Widget build(BuildContext context) {
    return TextFieldTapRegion(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          final index = (details.localPosition.dy / widget.lineHeight).floor();
          widget.controller.selection = _selectFromIndexes(index, index);
          widget.focusNode.requestFocus();
        },
        onPanStart: (details) {
          startIndex = (details.localPosition.dy / widget.lineHeight).floor();
          widget.controller.selection =
              _selectFromIndexes(startIndex, startIndex);
          widget.focusNode.requestFocus();
        },
        onPanUpdate: (details) {
          final lines = widget.controller.text.split("\n");
          final currIndex =
              (details.localPosition.dy / widget.lineHeight).floor();
          widget.controller.selection = _selectFromIndexes(
            startIndex,
            currIndex.clamp(0, lines.length - 1),
          );
          widget.focusNode.requestFocus();
        },
        child: widget.child,
      ),
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

class _EditorDecorator extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(fileProvider);

    return ListenableBuilder(
      listenable: Listenable.merge([
        controller,
        focusNode,
      ]),
      builder: (context, child) {
        return InputDecorator(
          textAlign: TextAlign.start,
          textAlignVertical: TextAlignVertical.center,
          baseStyle: style,
          decoration: InputDecoration(
            hintText: file == null ? hintText : null,
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

        return Consumer(
          builder: (context, ref, child) {
            final enableLineHighlighting =
                ref.watch(enableLineHighlightingProvider);
            return Stack(
              children: [
                if (controller.selection.isCollapsed && enableLineHighlighting)
                  Positioned(
                    top: sampleParagraph.height * (highlightedLine - 1),
                    height: sampleParagraph.height,
                    left: 0,
                    right: 0,
                    child: ColoredBox(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.2),
                    ),
                  ),
                child!,
              ],
            );
          },
          child: child,
        );
      },
      child: child,
    );
  }
}
