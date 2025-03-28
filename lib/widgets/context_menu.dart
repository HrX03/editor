import 'package:collection/collection.dart';
import 'package:editor/internal/theme.dart';
import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

class EditorContextMenu extends StatefulWidget {
  final List<ContextMenuEntry> entries;
  final MenuStyle? menuStyle;
  final ButtonStyle? menuItemStyle;
  final ButtonStyle? nestedMenuItemStyle;
  final MenuController? controller;
  final bool registerShortcuts;

  const EditorContextMenu({
    required this.entries,
    this.menuStyle,
    this.menuItemStyle,
    this.nestedMenuItemStyle,
    this.controller,
    this.registerShortcuts = true,
    super.key,
  });

  @override
  State<EditorContextMenu> createState() => _EditorContextMenuState();
}

class _EditorContextMenuState extends State<EditorContextMenu> {
  final _implicitMenuController = MenuController();
  MenuController get _menuController => widget.controller ?? _implicitMenuController;
  ShortcutRegistryEntry? _entry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.registerShortcuts) _registerShortcuts(widget.entries);
  }

  @override
  void didUpdateWidget(covariant EditorContextMenu old) {
    if (!const ListEquality().equals(widget.entries, old.entries) ||
        widget.registerShortcuts != old.registerShortcuts) {
      if (widget.registerShortcuts) _registerShortcuts(widget.entries);
    }

    super.didUpdateWidget(old);
  }

  @override
  void dispose() {
    _entry?.dispose();
    super.dispose();
  }

  void _registerShortcuts(List<ContextMenuEntry> entries) {
    _entry?.dispose();
    final shortcuts = _buildShortcuts(entries);
    _entry = ShortcutRegistry.of(context).addAll(shortcuts);
  }

  Map<MenuSerializableShortcut, Intent> _buildShortcuts(List<ContextMenuEntry> entries) {
    final result = <MenuSerializableShortcut, Intent>{};

    for (final selection in entries) {
      if (selection case ContextMenuNested()) {
        result.addAll(_buildShortcuts(selection.children));
      } else if (selection case ContextMenuItem()) {
        if (selection.shortcut != null && selection.onActivate != null) {
          result[selection.shortcut!] = VoidCallbackIntent(selection.onActivate!);
        }
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (ResponsiveBreakpoints.of(context).largerThan('COMPACT')) {
      return MenuBar(
        style: const MenuStyle(
          backgroundColor: WidgetStatePropertyAll(Colors.transparent),
          padding: WidgetStatePropertyAll(EdgeInsets.only(left: 8)),
          minimumSize: WidgetStatePropertyAll(Size(0, 40)),
        ),
        controller: _menuController,
        children: entriesToWidgets(
          entries: widget.entries,
          menuStyle: widget.menuStyle,
          menuItemStyle: widget.menuItemStyle,
          nestedMenuItemStyle: widget.nestedMenuItemStyle,
        ),
      );
    }

    return MenuAnchor(
      menuChildren: entriesToWidgets(
        entries: widget.entries,
        menuStyle: widget.menuStyle,
        menuItemStyle: widget.menuItemStyle,
        nestedMenuItemStyle: widget.nestedMenuItemStyle,
      ),
      controller: _menuController,
      style: widget.menuStyle,
      alignmentOffset: const Offset(4, 4),
      builder: (context, controller, child) {
        return IconButton(
          onPressed: controller.isOpen ? controller.close : controller.open,
          style: IconButton.styleFrom(shape: const RoundedRectangleBorder()),
          icon: const Icon(Icons.menu, size: 16),
        );
      },
    );
  }
}

List<Widget> entriesToWidgets({
  required List<ContextMenuEntry> entries,
  MenuStyle? menuStyle,
  ButtonStyle? menuItemStyle,
  ButtonStyle? nestedMenuItemStyle,
}) {
  return entries
      .map(
        (e) => e.render(
          menuStyle: menuStyle,
          menuItemStyle: menuItemStyle,
          nestedMenuItemStyle: nestedMenuItemStyle,
        ),
      )
      .toList();
}

List<Widget> entriesToWidgetsDefaultStyle({
  required List<ContextMenuEntry> entries,
  required BuildContext context,
}) {
  final menuStyle = getMenuStyle();
  final menuItemStyle = getMenuItemStyle(Theme.of(context));
  final nestedMenuItemStyle = getNestedMenuItemStyle(Theme.of(context));

  return entries
      .map(
        (e) => e.render(
          menuStyle: menuStyle,
          menuItemStyle: menuItemStyle,
          nestedMenuItemStyle: nestedMenuItemStyle,
        ),
      )
      .toList();
}

abstract class ContextMenuEntry {
  const ContextMenuEntry();

  Widget render({
    MenuStyle? menuStyle,
    ButtonStyle? menuItemStyle,
    ButtonStyle? nestedMenuItemStyle,
  });
}

class ContextMenuItem extends ContextMenuEntry {
  final String label;
  final MenuSerializableShortcut? shortcut;
  final VoidCallback? onActivate;
  final Widget? leading;
  final Widget? trailing;
  final ButtonStyle? style;

  const ContextMenuItem({
    required this.label,
    this.shortcut,
    this.onActivate,
    this.leading,
    this.trailing,
    this.style,
  });

  @override
  Widget render({
    MenuStyle? menuStyle,
    ButtonStyle? menuItemStyle,
    ButtonStyle? nestedMenuItemStyle,
  }) {
    return MenuItemButton(
      shortcut: shortcut,
      leadingIcon: leading,
      trailingIcon: trailing,
      style: style ?? menuItemStyle,
      onPressed: onActivate,
      child: Text(label),
    );
  }
}

class ContextMenuNested extends ContextMenuEntry {
  final String label;
  final List<ContextMenuEntry> children;
  final Widget? leading;
  final MenuStyle? menuStyle;
  final ButtonStyle? style;

  const ContextMenuNested({
    required this.label,
    required this.children,
    this.leading,
    this.menuStyle,
    this.style,
  });

  @override
  Widget render({
    MenuStyle? menuStyle,
    ButtonStyle? menuItemStyle,
    ButtonStyle? nestedMenuItemStyle,
  }) {
    return SubmenuButton(
      leadingIcon: leading,
      menuChildren:
          children
              .map(
                (i) => i.render(
                  menuStyle: menuStyle,
                  menuItemStyle: menuItemStyle,
                  nestedMenuItemStyle: nestedMenuItemStyle,
                ),
              )
              .toList(),
      alignmentOffset: const Offset(4, 8),
      style: style ?? nestedMenuItemStyle,
      menuStyle: menuStyle ?? menuStyle,
      child: Text(label),
    );
  }
}

class ContextMenuDivider extends ContextMenuEntry {
  const ContextMenuDivider();

  @override
  Widget render({
    MenuStyle? menuStyle,
    ButtonStyle? menuItemStyle,
    ButtonStyle? nestedMenuItemStyle,
  }) {
    return const Divider(thickness: 1);
  }
}

class ContextMenuListenableWrapper extends ContextMenuEntry {
  final Listenable listenable;
  final ContextMenuEntry Function() builder;

  const ContextMenuListenableWrapper({required this.listenable, required this.builder});

  @override
  Widget render({
    MenuStyle? menuStyle,
    ButtonStyle? menuItemStyle,
    ButtonStyle? nestedMenuItemStyle,
  }) {
    return ListenableBuilder(
      listenable: listenable,
      builder:
          (context, child) => builder().render(
            menuStyle: menuStyle,
            menuItemStyle: menuItemStyle,
            nestedMenuItemStyle: nestedMenuItemStyle,
          ),
    );
  }
}
