import 'dart:math';

import 'package:editor/internal/environment.dart';
import 'package:editor/internal/paste.dart';
import 'package:editor/internal/preferences.dart';
import 'package:editor/internal/theme.dart';
import 'package:editor/widgets/context_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/plaintext.dart';

class TextEditor extends ConsumerStatefulWidget {
  const TextEditor({super.key});

  @override
  ConsumerState<TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends ConsumerState<TextEditor> {
  final verticalScrollController = ScrollController();
  final horizontalScrollController = ScrollController();
  final lineListenable = ValueNotifier<CodeIndicatorValue?>(null);
  final menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final currFile = ref.watch(fileProvider);
    final language = ref.watch(fileLanguageProvider);
    final controller = ref.watch(editorControllerProvider);
    final findController = ref.watch(findControllerProvider);
    final enableLineNumberColumn = ref.watch(enableLineNumberColumnProvider);
    final enableLineWrapping = ref.watch(enableLineWrapProvider);
    final canPaste = ref.watch(pasteContentsProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: EditorContextMenu(
            controller: menuController,
            entries: [
              ContextMenuItem(
                label: "Copy",
                onActivate: controller.copy,
                shortcut: const SingleActivator(LogicalKeyboardKey.keyC, control: true),
              ),
              ContextMenuItem(
                label: "Cut",
                onActivate: controller.cut,
                shortcut: const SingleActivator(LogicalKeyboardKey.keyX, control: true),
              ),
              ContextMenuListenableWrapper(
                listenable: canPaste,
                builder:
                    () => ContextMenuItem(
                      label: "Paste",
                      onActivate: canPaste.value ? controller.paste : null,
                      shortcut: const SingleActivator(LogicalKeyboardKey.keyV, control: true),
                    ),
              ),
              ContextMenuListenableWrapper(
                listenable: controller,
                builder:
                    () => ContextMenuItem(
                      label: "Delete",
                      onActivate:
                          !controller.selection.isCollapsed ? controller.deleteSelection : null,
                      shortcut: const SingleActivator(LogicalKeyboardKey.cancel),
                    ),
              ),
              const ContextMenuDivider(),
              ContextMenuListenableWrapper(
                listenable: controller,
                builder:
                    () => ContextMenuItem(
                      label: "Undo",
                      onActivate: controller.canUndo ? controller.undo : null,
                      shortcut: const SingleActivator(LogicalKeyboardKey.keyZ, control: true),
                    ),
              ),
              ContextMenuListenableWrapper(
                listenable: controller,
                builder:
                    () => ContextMenuItem(
                      label: "Redo",
                      onActivate: controller.canRedo ? controller.redo : null,
                      shortcut: const SingleActivator(
                        LogicalKeyboardKey.keyZ,
                        control: true,
                        shift: true,
                      ),
                    ),
              ),
              const ContextMenuDivider(),
              ContextMenuItem(
                label: "Select all",
                onActivate: controller.selectAll,
                shortcut: const SingleActivator(LogicalKeyboardKey.keyA, control: true),
              ),
              const ContextMenuDivider(),
              ContextMenuItem(
                label: "Find",
                onActivate: findController.findMode,
                shortcut: const SingleActivator(LogicalKeyboardKey.keyF, control: true),
              ),
              ContextMenuItem(
                label: "Replace",
                onActivate: findController.replaceMode,
                shortcut: const SingleActivator(LogicalKeyboardKey.keyH, control: true),
              ),
            ],
            registerShortcuts: false,
            menuStyle: getMenuStyle(),
            menuItemStyle: getMenuItemStyle(Theme.of(context)),
            nestedMenuItemStyle: getNestedMenuItemStyle(Theme.of(context)),
            builder: (context, menuController) => const SizedBox(),
          ),
        ),
        Positioned.fill(
          child: CodeEditor(
            scrollController: CodeScrollController(
              verticalScroller: verticalScrollController,
              horizontalScroller: horizontalScrollController,
            ),
            scrollbarBuilder: (context, child, details) {
              return Scrollbar(controller: details.controller, child: child);
            },
            findController: findController,
            controller: controller,
            findBuilder:
                (context, controller, readonly) => CodeFindPanelView(
                  controller: controller,
                  readOnly: readonly,
                  margin: const EdgeInsets.all(16),
                  inputTextColor: Theme.of(context).colorScheme.onSurface,
                  iconColor: Theme.of(context).colorScheme.onSurface,
                  resultFontColor: Theme.of(context).colorScheme.onSurface,
                ),
            padding: const EdgeInsets.only(top: 8.0, bottom: 12.0, left: 16),
            indicatorBuilder:
                enableLineNumberColumn
                    ? (context, editingController, chunkController, notifier) => Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: DefaultCodeLineNumber(notifier: notifier, controller: controller),
                    )
                    : null,
            overlayIndicatorBuilder: (
              context,
              editingController,
              chunkController,
              notifier,
              child,
            ) {
              return _LineHighlightLayer(
                notifier: notifier,
                controller: controller,
                enableLineHighlighting: ref.watch(enableLineHighlightingProvider),
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                child: child,
              );
            },
            wordWrap: enableLineWrapping,
            toolbarController: _MenuContextToolbarController(menuController),
            shortcutsActivatorsBuilder: const _OverrideCodeShortcutsActivatorsBuilder({
              CodeShortcutType.cursorMoveLineStart: [SingleActivator(LogicalKeyboardKey.home)],
              CodeShortcutType.cursorMoveLineEnd: [SingleActivator(LogicalKeyboardKey.end)],
              CodeShortcutType.cursorMoveWordBoundaryBackward: [
                SingleActivator(LogicalKeyboardKey.arrowLeft, control: true),
              ],
              CodeShortcutType.cursorMoveWordBoundaryForward: [
                SingleActivator(LogicalKeyboardKey.arrowRight, control: true),
              ],
              CodeShortcutType.selectionExtendWordBoundaryForward: [
                SingleActivator(LogicalKeyboardKey.arrowLeft, control: true, shift: true),
              ],
              CodeShortcutType.selectionExtendWordBoundaryBackward: [
                SingleActivator(LogicalKeyboardKey.arrowRight, control: true, shift: true),
              ],
              CodeShortcutType.wordDeleteForward: [
                SingleActivator(LogicalKeyboardKey.delete, control: true),
              ],
              CodeShortcutType.wordDeleteBackward: [
                SingleActivator(LogicalKeyboardKey.backspace, control: true),
              ],
            }),
            //toolbarController: SelectionToolbarController(),
            style: CodeEditorStyle(
              fontFamily: "FiraCode",
              fontSize: 14,
              fontHeight: 1.3,
              textColor: Theme.of(context).colorScheme.onSurface,
              codeTheme: CodeHighlightTheme(
                languages: {
                  currFile != null ? extension(currFile.path) : "": CodeHighlightThemeMode(
                    mode: language ?? langPlaintext,
                  ),
                },
                theme: Theme.of(context).extension<HighlightThemeExtension>()!.editorTheme,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverrideCodeShortcutsActivatorsBuilder extends DefaultCodeShortcutsActivatorsBuilder {
  final Map<CodeShortcutType, List<ShortcutActivator>> overrides;

  const _OverrideCodeShortcutsActivatorsBuilder(this.overrides);

  @override
  List<ShortcutActivator>? build(CodeShortcutType type) {
    return overrides[type] ?? super.build(type);
  }
}

const EdgeInsetsGeometry _kDefaultFindMargin = EdgeInsets.only(right: 10);
const double _kDefaultFindPanelWidth = 360;
const double _kDefaultFindPanelHeight = 36;
const double _kDefaultReplacePanelHeight = _kDefaultFindPanelHeight * 2;
const double _kDefaultFindIconSize = 16;
const double _kDefaultFindIconWidth = 30;
const double _kDefaultFindIconHeight = 30;
const double _kDefaultFindInputFontSize = 13;
const double _kDefaultFindResultFontSize = 12;
const EdgeInsetsGeometry _kDefaultFindPadding = EdgeInsets.only(
  left: 5,
  right: 5,
  top: 2.5,
  bottom: 2.5,
);
const EdgeInsetsGeometry _kDefaultFindInputContentPadding = EdgeInsets.only(left: 5, right: 5);

class CodeFindPanelView extends StatelessWidget implements PreferredSizeWidget {
  final CodeFindController controller;
  final EdgeInsetsGeometry margin;
  final bool readOnly;
  final Color? iconColor;
  final Color? iconSelectedColor;
  final double iconSize;
  final double inputFontSize;
  final double resultFontSize;
  final Color? inputTextColor;
  final Color? resultFontColor;
  final EdgeInsetsGeometry padding;
  final InputDecoration decoration;

  const CodeFindPanelView({
    super.key,
    required this.controller,
    this.margin = _kDefaultFindMargin,
    required this.readOnly,
    this.iconSelectedColor,
    this.iconColor,
    this.iconSize = _kDefaultFindIconSize,
    this.inputFontSize = _kDefaultFindInputFontSize,
    this.resultFontSize = _kDefaultFindResultFontSize,
    this.inputTextColor,
    this.resultFontColor,
    this.padding = _kDefaultFindPadding,
    this.decoration = const InputDecoration(
      filled: true,
      contentPadding: _kDefaultFindInputContentPadding,
      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(2)), gapPadding: 0),
    ),
  });

  @override
  Size get preferredSize => Size.zero;

  @override
  Widget build(BuildContext context) {
    if (controller.value == null) {
      return const SizedBox();
    }
    return Container(
      margin: margin,
      alignment: Alignment.topRight,
      child: Material(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
        child: Container(
          height:
              controller.value == null
                  ? 0
                  : (controller.value!.replaceMode
                      ? _kDefaultReplacePanelHeight
                      : _kDefaultFindPanelHeight),
          margin: const EdgeInsets.all(4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _kDefaultFindPanelWidth,
              child: Column(
                children: [
                  _buildFindInputView(context),
                  if (controller.value!.replaceMode) _buildReplaceInputView(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFindInputView(BuildContext context) {
    final CodeFindValue value = controller.value!;
    final String result;
    if (value.result == null) {
      result = 'none';
    } else {
      result = '${value.result!.index + 1}/${value.result!.matches.length}';
    }
    return Row(
      children: [
        SizedBox(
          width: _kDefaultFindPanelWidth / 1.75,
          height: _kDefaultFindPanelHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildTextField(
                context: context,
                controller: controller.findInputController,
                focusNode: controller.findInputFocusNode,
                iconsWidth: _kDefaultFindIconWidth * 1.5,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildCheckText(
                    context: context,
                    text: 'Aa',
                    checked: value.option.caseSensitive,
                    onPressed: () {
                      controller.toggleCaseSensitive();
                    },
                  ),
                  _buildCheckText(
                    context: context,
                    text: '.*',
                    checked: value.option.regex,
                    onPressed: () {
                      controller.toggleRegex();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        Text(result, style: TextStyle(color: resultFontColor, fontSize: resultFontSize)),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildIconButton(
                onPressed:
                    value.result == null
                        ? null
                        : () {
                          controller.previousMatch();
                        },
                icon: Icons.arrow_upward,
                tooltip: 'Previous',
              ),
              _buildIconButton(
                onPressed:
                    value.result == null
                        ? null
                        : () {
                          controller.nextMatch();
                        },
                icon: Icons.arrow_downward,
                tooltip: 'Next',
              ),
              _buildIconButton(
                onPressed: () {
                  controller.close();
                },
                icon: Icons.close,
                tooltip: 'Close',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReplaceInputView(BuildContext context) {
    final CodeFindValue value = controller.value!;
    return Row(
      children: [
        SizedBox(
          width: _kDefaultFindPanelWidth / 1.75,
          height: _kDefaultFindPanelHeight,
          child: _buildTextField(
            context: context,
            controller: controller.replaceInputController,
            focusNode: controller.replaceInputFocusNode,
          ),
        ),
        _buildIconButton(
          onPressed:
              value.result == null
                  ? null
                  : () {
                    controller.replaceMatch();
                  },
          icon: Icons.done,
          tooltip: 'Replace',
        ),
        _buildIconButton(
          onPressed:
              value.result == null
                  ? null
                  : () {
                    controller.replaceAllMatches();
                  },
          icon: Icons.done_all,
          tooltip: 'Replace All',
        ),
      ],
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required FocusNode focusNode,
    double iconsWidth = 0,
  }) {
    return Padding(
      padding: padding,
      child: TextField(
        focusNode: focusNode,
        style: TextStyle(color: inputTextColor, fontSize: inputFontSize),
        decoration: decoration.copyWith(
          contentPadding: (decoration.contentPadding ?? EdgeInsets.zero).add(
            EdgeInsets.only(right: iconsWidth),
          ),
        ),
        controller: controller,
      ),
    );
  }

  Widget _buildCheckText({
    required BuildContext context,
    required String text,
    required bool checked,
    required VoidCallback onPressed,
  }) {
    final Color selectedColor = iconSelectedColor ?? Theme.of(context).primaryColor;
    return GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: _kDefaultFindIconWidth * 0.75,
          child: Text(
            text,
            style: TextStyle(color: checked ? selectedColor : iconColor, fontSize: inputFontSize),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, VoidCallback? onPressed, String? tooltip}) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: iconSize),
      constraints: const BoxConstraints(
        maxWidth: _kDefaultFindIconWidth,
        maxHeight: _kDefaultFindIconHeight,
      ),
      tooltip: tooltip,
      splashRadius: max(_kDefaultFindIconWidth, _kDefaultFindIconHeight) / 2,
    );
  }
}

class DeclarativeCustomPainter extends CustomPainter {
  final void Function(Canvas canvas, Size size) onPaint;
  final bool Function() onShouldRepaint;

  const DeclarativeCustomPainter({required this.onPaint, required this.onShouldRepaint});

  @override
  void paint(Canvas canvas, Size size) => onPaint(canvas, size);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => onShouldRepaint();
}

class _MenuContextToolbarController extends SelectionToolbarController {
  final MenuController menuController;

  _MenuContextToolbarController(this.menuController);

  @override
  void show({
    required BuildContext context,
    required CodeLineEditingController controller,
    required TextSelectionToolbarAnchors anchors,
    Rect? renderRect,
    required LayerLink layerLink,
    required ValueNotifier<bool> visibility,
  }) {
    menuController.open(position: anchors.primaryAnchor - const Offset(0, 32));
  }

  @override
  void hide(BuildContext context) {
    // menuController.close();
  }
}

class _LineHighlightLayer extends SingleChildRenderObjectWidget {
  final CodeLineEditingController controller;
  final CodeIndicatorValueNotifier notifier;
  final bool enableLineHighlighting;
  final Color color;

  const _LineHighlightLayer({
    required this.controller,
    required this.notifier,
    required this.enableLineHighlighting,
    required this.color,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderLineHighlightLayer(
    controller: controller,
    notifier: notifier,
    enableLineHighlighting: enableLineHighlighting,
    color: color,
  );

  @override
  void updateRenderObject(BuildContext context, covariant _RenderLineHighlightLayer renderObject) {
    renderObject
      ..controller = controller
      ..notifier = notifier
      ..enableLineHighlighting = enableLineHighlighting
      ..color = color;
    super.updateRenderObject(context, renderObject);
  }
}

class _RenderLineHighlightLayer extends RenderProxyBox {
  CodeLineEditingController _controller;
  CodeIndicatorValueNotifier _notifier;
  bool _enableLineHighlighting;
  Color _color;

  _RenderLineHighlightLayer({
    required CodeLineEditingController controller,
    required CodeIndicatorValueNotifier notifier,
    required bool enableLineHighlighting,
    required Color color,
  }) : _controller = controller,
       _notifier = notifier,
       _enableLineHighlighting = enableLineHighlighting,
       _color = color;

  // ignore: avoid_setters_without_getters
  set controller(CodeLineEditingController value) {
    if (_controller == value) {
      return;
    }
    if (attached) {
      _controller.removeListener(_onCodeLineChanged);
    }
    _controller = value;
    if (attached) {
      _controller.addListener(_onCodeLineChanged);
    }
    _onCodeLineChanged();
  }

  // ignore: avoid_setters_without_getters
  set notifier(CodeIndicatorValueNotifier value) {
    if (_notifier == value) {
      return;
    }
    if (attached) {
      _notifier.removeListener(markNeedsPaint);
    }
    _notifier = value;
    if (attached) {
      _notifier.addListener(markNeedsPaint);
    }
    markNeedsPaint();
  }

  // ignore: avoid_setters_without_getters
  set color(Color value) {
    if (_color == value) {
      return;
    }
    _color = value;
    markNeedsPaint();
  }

  // ignore: avoid_setters_without_getters
  set enableLineHighlighting(bool value) {
    if (_enableLineHighlighting == value) {
      return;
    }
    _enableLineHighlighting = value;
    markNeedsPaint();
  }

  @override
  void attach(covariant PipelineOwner owner) {
    _controller.addListener(_onCodeLineChanged);
    _notifier.addListener(markNeedsPaint);
    super.attach(owner);
  }

  @override
  void detach() {
    _controller.removeListener(_onCodeLineChanged);
    _notifier.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Canvas canvas = context.canvas;
    final CodeIndicatorValue? value = _notifier.value;

    if (value == null || value.paragraphs.isEmpty) {
      return super.paint(context, offset);
    }

    if (_enableLineHighlighting && _controller.selection.isCollapsed) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height));
      for (final CodeLineRenderParagraph paragraph in value.paragraphs) {
        if (paragraph.index != value.focusedIndex) continue;

        canvas.drawRect(
          Rect.fromLTWH(0, paragraph.top, size.width, paragraph.height),
          Paint()..color = _color,
        );
      }
      canvas.restore();
    }

    super.paint(context, offset);
  }

  void _onCodeLineChanged() {
    if (!attached) {
      return;
    }

    markNeedsPaint();
  }
}
