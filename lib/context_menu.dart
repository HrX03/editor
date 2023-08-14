import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

sealed class ContextMenuEntry {
  const ContextMenuEntry();
}

class ContextMenuItem extends ContextMenuEntry {
  final String label;
  final MenuSerializableShortcut? shortcut;
  final VoidCallback? onActivate;
  final Widget? leading;
  final Widget? trailing;

  const ContextMenuItem({
    required this.label,
    this.shortcut,
    this.onActivate,
    this.leading,
    this.trailing,
  });
}

class ContextMenuNested extends ContextMenuEntry {
  final String label;
  final List<ContextMenuEntry> children;
  final Widget? leading;

  const ContextMenuNested({
    required this.label,
    required this.children,
    this.leading,
  });
}

class ContextMenuDivider extends ContextMenuEntry {
  const ContextMenuDivider();
}

class EditorContextMenu extends StatefulWidget {
  final Widget Function(BuildContext context, MenuController controller)
      builder;
  final List<ContextMenuEntry> entries;
  final MenuStyle? menuStyle;
  final ButtonStyle? menuItemStyle;
  final ButtonStyle? nestedMenuItemStyle;

  const EditorContextMenu({
    required this.builder,
    required this.entries,
    this.menuStyle,
    this.menuItemStyle,
    this.nestedMenuItemStyle,
    super.key,
  });

  @override
  State<EditorContextMenu> createState() => _EditorContextMenuState();
}

class _EditorContextMenuState extends State<EditorContextMenu> {
  ShortcutRegistryEntry? _entry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registerShortcuts(widget.entries);
  }

  @override
  void didUpdateWidget(covariant EditorContextMenu old) {
    if (!const ListEquality().equals(widget.entries, old.entries)) {
      _registerShortcuts(widget.entries);
    }

    super.didUpdateWidget(old);
  }

  @override
  void dispose() {
    _entry?.dispose();
    super.dispose();
  }

  Widget _buildItem(ContextMenuEntry item) {
    return switch (item) {
      final ContextMenuItem item => MenuItemButton(
          shortcut: item.shortcut,
          leadingIcon: item.leading,
          trailingIcon: item.trailing,
          style: widget.menuItemStyle,
          onPressed: item.onActivate,
          child: Text(item.label),
        ),
      final ContextMenuNested nested => SubmenuButton(
          leadingIcon: nested.leading,
          menuChildren: nested.children.map(_buildItem).toList(),
          alignmentOffset: const Offset(4, 8),
          style: widget.nestedMenuItemStyle,
          menuStyle: widget.menuStyle,
          child: Text(nested.label),
        ),
      ContextMenuDivider() => const Divider(thickness: 1),
    };
  }

  void _registerShortcuts(List<ContextMenuEntry> entries) {
    _entry?.dispose();
    final shortcuts = _buildShortcuts(entries);
    _entry = ShortcutRegistry.of(context).addAll(shortcuts);
  }

  Map<MenuSerializableShortcut, Intent> _buildShortcuts(
    List<ContextMenuEntry> entries,
  ) {
    final result = <MenuSerializableShortcut, Intent>{};

    for (final selection in entries) {
      if (selection case ContextMenuNested()) {
        result.addAll(_buildShortcuts(selection.children));
      } else if (selection case ContextMenuItem()) {
        if (selection.shortcut != null && selection.onActivate != null) {
          result[selection.shortcut!] =
              VoidCallbackIntent(selection.onActivate!);
        }
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: widget.entries.map(_buildItem).toList(),
      style: widget.menuStyle,
      alignmentOffset: const Offset(4, 4),
      builder: (context, controller, child) =>
          widget.builder(context, controller),
    );
  }
}
