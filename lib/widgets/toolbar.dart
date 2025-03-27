import 'package:editor/internal/environment.dart';
import 'package:editor/internal/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_highlight/languages/all.dart';

class EditorToolbar extends ConsumerWidget {
  const EditorToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(editorControllerProvider);
    final currLanguage = ref.watch(fileLanguageProvider);
    final currEncoding = ref.watch(encodingProvider);

    return Row(
      children: [
        const SizedBox(width: 16),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final lineIndex = controller.selection.endIndex;
            final lineOffset = controller.selection.endOffset;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                "Ln ${lineIndex + 1}, Col ${lineOffset + 1}",
                style: const TextStyle(fontSize: 12),
              ),
            );
          },
        ),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final selected = !controller.selection.isCollapsed ? controller.selectedText.length : 0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                "${selected > 0 ? "$selected of " : ""}${controller.text.length} characters",
                style: const TextStyle(fontSize: 12),
              ),
            );
          },
        ),
        const Spacer(),
        PopupMenuButton<EncodingType>(
          itemBuilder:
              (context) => [
                for (final encoding in EncodingType.values)
                  PopupMenuItem(
                    value: encoding,
                    height: 32,
                    child: Text(encoding.displayName, style: const TextStyle(fontSize: 12)),
                  ),
              ],
          onSelected: (value) {
            final environment = ref.read(editorEnvironmentProvider.notifier);
            environment.reopenWithEncoding(value);
          },
          tooltip: "Set file encoding",
          initialValue: currEncoding,
          child: SizedBox(
            height: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Text(currEncoding.displayName, style: const TextStyle(fontSize: 12)),
              ),
            ),
          ),
        ),
        PopupMenuButton<String?>(
          itemBuilder: (context) {
            final children = <PopupMenuEntry<String?>>[];
            final alphaRegex = RegExp("[A-Za-z]");
            String? lastInitial;

            for (final lang in sortedLanguages) {
              final initial = (lang.value.name ?? lang.key).characters.first.toLowerCase();
              final fixedInitial = alphaRegex.hasMatch(initial) ? initial : null;

              if (fixedInitial != lastInitial || children.isEmpty) {
                lastInitial = fixedInitial;
                children.add(_LabeledPopupMenuDivider(label: fixedInitial?.toUpperCase() ?? "#"));
              }

              children.add(
                PopupMenuItem(
                  value: lang.key,
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(lang.value.name ?? lang.key, style: const TextStyle(fontSize: 12)),
                ),
              );
            }

            return [
              const PopupMenuItem(
                value: '!none!', //special value cuz null doesn't work idk
                height: 32,
                child: Text("Plain text", style: TextStyle(fontSize: 12)),
              ),
              ...children,
            ];
          },
          onSelected: (value) {
            final environment = ref.read(editorEnvironmentProvider.notifier);
            environment.setLanguage(value != '!none!' ? builtinAllLanguages[value] : null);
          },
          menuPadding: const EdgeInsets.only(top: 12, bottom: 4),
          tooltip: "Set language mode",
          initialValue: currLanguage?.name,
          child: SizedBox(
            height: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Text(
                  currLanguage?.name ?? "Plain text",
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }
}

class _LabeledPopupMenuDivider extends PopupMenuDivider {
  final String label;

  const _LabeledPopupMenuDivider({required this.label});

  @override
  State<_LabeledPopupMenuDivider> createState() => _LabeledPopupMenuDividerState();
}

class _LabeledPopupMenuDividerState extends State<_LabeledPopupMenuDivider> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(width: 8, child: Divider(height: widget.height)),
          const SizedBox(width: 8),
          Text(widget.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Divider(height: widget.height)),
        ],
      ),
    );
  }
}
