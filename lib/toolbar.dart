import 'package:editor/environment.dart';
import 'package:editor/listenable.dart';
import 'package:flutter/material.dart';
import 'package:highlight/languages/all.dart';

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
        ListenableWatcher(
          listenable: currLanguage,
          child: PopupMenuButton<String?>(
            itemBuilder: (context) => [
              const PopupMenuItem(child: Text("None")),
              for (final lang in allLanguages.entries)
                PopupMenuItem(
                  value: lang.key,
                  child: Text(lang.key),
                ),
            ],
            onSelected: (value) {
              environment.editorLanguage = value;
            },
            tooltip: "Set language mode",
            initialValue: currLanguage.value,
            child: SizedBox(
              height: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Center(
                  child: Text(currLanguage.value ?? "None"),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
