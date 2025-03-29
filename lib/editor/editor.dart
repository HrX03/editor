import 'package:editor/editor/find.dart';
import 'package:editor/editor/line.dart';
import 'package:editor/internal/environment.dart';
import 'package:editor/internal/menus.dart';
import 'package:editor/internal/preferences.dart';
import 'package:editor/internal/theme.dart';
import 'package:editor/widgets/context_menu.dart';
import 'package:flutter/material.dart';
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
    final currFile = ref.watch(pathProvider);
    final language = ref.watch(editorLanguageProvider);
    final controller = ref.watch(editorControllerProvider);
    final findController = ref.watch(findControllerProvider);
    final enableLineNumberColumn = ref.watch(enableLineNumberColumnProvider);
    final enableLineWrapping = ref.watch(enableLineWrapProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: MenuAnchor(
            controller: menuController,
            menuChildren: entriesToWidgetsDefaultStyle(
              context: context,
              entries: getEditMenuEntries(ref),
            ),
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
              return LineHighlightLayer(
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
            style: CodeEditorStyle(
              fontFamily: "FiraCode",
              fontSize: 14,
              fontHeight: 1.3,
              textColor: Theme.of(context).colorScheme.onSurface,
              codeTheme: CodeHighlightTheme(
                languages: {
                  currFile != null ? extension(currFile) : "": CodeHighlightThemeMode(
                    mode: language?.$2 ?? langPlaintext,
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
    menuController.open(position: anchors.primaryAnchor - const Offset(0, 40));
  }

  @override
  void hide(BuildContext context) {}
}
