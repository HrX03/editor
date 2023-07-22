import 'package:collection/collection.dart';
import 'package:editor/environment.dart';
import 'package:flutter/material.dart';
import 'package:highlighting/languages/all.dart';

class EditorToolbar extends StatelessWidget {
  const EditorToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final environment = EditorEnvironment.of(context);
    final controller = environment.textController;
    final currLanguage = environment.editorLanguageNotifier;

    return Row(
      children: [
        const Spacer(),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final position =
                controller.selection.start > controller.selection.end
                    ? controller.selection.base
                    : controller.selection.extent;
            final prevText =
                position.offset > 0 && position.offset <= controller.text.length
                    ? controller.text.substring(0, position.offset)
                    : "";
            final prevTextParts = prevText.split("\n");
            final selected = !controller.selection.isCollapsed
                ? controller.selection.textInside(controller.text).length
                : 0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                "Line: ${prevTextParts.length}, Col: ${prevTextParts.last.length + 1}${selected > 0 ? " ($selected selected)" : ""}",
              ),
            );
          },
        ),
        ValueListenableBuilder(
          valueListenable: currLanguage,
          builder: (context, value, child) {
            return PopupMenuButton<String?>(
              itemBuilder: (context) {
                final sortedLanguages = allLanguages.values.sorted((a, b) {
                  final first = a.name ?? a.id;
                  final last = b.name ?? b.id;

                  return first.toLowerCase().compareTo(last.toLowerCase());
                });

                final children = <PopupMenuEntry<String?>>[];
                final alphaRegex = RegExp("[A-Za-z]");
                String? lastInitial;

                for (final lang in sortedLanguages) {
                  final initial =
                      (lang.name ?? lang.id).characters.first.toLowerCase();
                  final fixedInitial =
                      alphaRegex.hasMatch(initial) ? initial : null;

                  if (fixedInitial != lastInitial || children.isEmpty) {
                    lastInitial = fixedInitial;
                    children.add(
                      _LabeledPopupMenuDivider(
                        label: fixedInitial?.toUpperCase() ?? "#",
                      ),
                    );
                  }

                  children.add(
                    PopupMenuItem(
                      value: lang.id,
                      child: Text(lang.name ?? lang.id),
                    ),
                  );
                }
                return [
                  const PopupMenuItem(child: Text("Plain text")),
                  ...children,
                ];
              },
              onSelected: (value) {
                environment.editorLanguage = allLanguages[value];
              },
              tooltip: "Set language mode",
              initialValue: value?.id,
              child: SizedBox(
                height: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Center(
                    child: Text(value?.name ?? "Plain text"),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LabeledPopupMenuDivider extends PopupMenuDivider {
  final String label;

  const _LabeledPopupMenuDivider({required this.label});

  @override
  State<_LabeledPopupMenuDivider> createState() =>
      _LabeledPopupMenuDividerState();
}

class _LabeledPopupMenuDividerState extends State<_LabeledPopupMenuDivider> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          child: Divider(height: widget.height),
        ),
        const SizedBox(width: 8),
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(height: widget.height),
        ),
      ],
    );
  }
}
