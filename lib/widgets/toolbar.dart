import 'package:editor/internal/environment.dart';
import 'package:editor/internal/extensions.dart';
import 'package:editor/internal/theme.dart';
import 'package:editor/widgets/context_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_highlight/languages/all.dart';

class EditorToolbar extends ConsumerWidget {
  const EditorToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(editorControllerProvider);
    final (currLanguageKey, currLanguage) = ref.watch(fileLanguageProvider) ?? (null, null);
    final currEncoding = ref.watch(encodingProvider);

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 8),
      child: Row(
        spacing: 16,
        children: [
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final lineIndex = controller.selection.endIndex;
              final lineOffset = controller.selection.endOffset;

              return Text(
                "Ln ${lineIndex + 1}, Col ${lineOffset + 1}",
                style: const TextStyle(fontSize: 12),
              );
            },
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final selected =
                  !controller.selection.isCollapsed ? controller.selectedText.length : 0;

              return Text(
                "${selected > 0 ? "$selected of " : ""}${controller.text.length} characters",
                style: const TextStyle(fontSize: 12),
              );
            },
          ),
          const Spacer(),
          MenuBar(
            style: const MenuStyle(backgroundColor: WidgetStatePropertyAll(Colors.transparent)),
            children: entriesToWidgetsDefaultStyle(
              entries: [
                ContextMenuNested(
                  label: currEncoding.displayName,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    textStyle: Theme.of(context).primaryTextTheme.bodySmall,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  children: [
                    for (final encoding in EncodingType.values)
                      ContextMenuItem(
                        onActivate: () {
                          final environment = ref.read(editorEnvironmentProvider.notifier);
                          environment.reopenWithEncoding(encoding);
                        },
                        label: encoding.displayName,
                      ),
                  ],
                ),
                ContextMenuNested(
                  label: currLanguage?.name ?? "Plain text",
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    textStyle: Theme.of(context).primaryTextTheme.bodySmall,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  children: () {
                    final children = <ContextMenuEntry>[];
                    final alphaRegex = RegExp("[A-Za-z]");
                    String? lastInitial;

                    for (final lang in sortedLanguages) {
                      final initial = (lang.value.name ?? lang.key).characters.first.toLowerCase();
                      final fixedInitial = alphaRegex.hasMatch(initial) ? initial : null;

                      if (fixedInitial != lastInitial || children.isEmpty) {
                        lastInitial = fixedInitial;
                        children.add(
                          _ContextMenuLabeledDivider(label: fixedInitial?.toUpperCase() ?? "#"),
                        );
                      }

                      children.add(
                        ContextMenuItem(
                          style: getMenuItemStyle(Theme.of(context)),
                          onActivate: () {
                            final environment = ref.read(editorEnvironmentProvider.notifier);
                            environment.setLanguage((lang.key, builtinAllLanguages[lang.key]!));
                          },
                          label: lang.value.name ?? lang.key,
                        ),
                      );
                    }

                    return [
                      ContextMenuItem(
                        onActivate: () {
                          final environment = ref.read(editorEnvironmentProvider.notifier);
                          environment.setLanguage(null);
                        },
                        label: "Plain text",
                      ),
                      ...children,
                    ];
                  }(),
                ),
              ],
              context: context,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextMenuLabeledDivider extends ContextMenuEntry {
  final String label;

  const _ContextMenuLabeledDivider({required this.label});

  @override
  Widget render({
    MenuStyle? menuStyle,
    ButtonStyle? menuItemStyle,
    ButtonStyle? nestedMenuItemStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          const SizedBox(width: 8, child: Divider()),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
