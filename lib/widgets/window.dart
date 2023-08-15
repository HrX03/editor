import 'dart:math';

import 'package:editor/editor/environment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

class WindowBar extends StatefulWidget implements PreferredSizeWidget {
  final Widget? title;

  const WindowBar({
    this.title,
    super.key,
  });

  @override
  State<WindowBar> createState() => _WindowBarState();

  @override
  Size get preferredSize => const Size.fromHeight(32);
}

class _WindowBarState extends State<WindowBar> with WindowListener {
  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    setState(() {});
  }

  @override
  void onWindowUnmaximize() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Stack(
      fit: StackFit.expand,
      children: [
        const DragToMoveArea(child: SizedBox.expand()),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (widget.title != null) const SizedBox(width: 0),
            if (widget.title != null)
              SizedBox(height: double.infinity, child: widget.title),
            const Spacer(),
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  WindowCaptionButton.minimize(
                    brightness: brightness,
                    onPressed: () async {
                      final isMinimized = await windowManager.isMinimized();
                      if (isMinimized) {
                        windowManager.restore();
                      } else {
                        windowManager.minimize();
                      }
                    },
                  ),
                  FutureBuilder<bool>(
                    future: windowManager.isMaximized(),
                    builder:
                        (BuildContext context, AsyncSnapshot<bool> snapshot) {
                      if (snapshot.data == true) {
                        return WindowCaptionButton.unmaximize(
                          brightness: brightness,
                          onPressed: () {
                            windowManager.unmaximize();
                          },
                        );
                      }
                      return WindowCaptionButton.maximize(
                        brightness: brightness,
                        onPressed: () {
                          windowManager.maximize();
                        },
                      );
                    },
                  ),
                  WindowCaptionButton.close(
                    brightness: brightness,
                    onPressed: () {
                      windowManager.close();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        /* Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              width: 480,
              height: double.infinity,
              child: Material(
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surface,
                surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
                elevation: 2,
                child: InkWell(
                  onTap: CommandPalette.of(context).open,
                  child: Center(
                    child: Text("Command palette"),
                  ),
                ),
              ),
            ),
          ),
        ), */
      ],
    );
  }
}

class WindowTitle extends StatelessWidget {
  const WindowTitle();

  @override
  Widget build(BuildContext context) {
    final environment = EditorEnvironment.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        environment.editorFile,
        environment.textController,
      ]),
      builder: (context, child) {
        final file = environment.editorFile.file;
        final text = environment.textController.text;
        final hasEdits = environment.hasEdits;

        final firstLine = text.split("\n").first;
        String fileName =
            firstLine.substring(0, min(firstLine.length, 45)).trim();
        fileName = fileName.isNotEmpty ? fileName : "Untitled";

        return Row(
          children: [
            Text(
              file != null ? p.basename(file.path) : fileName,
            ),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: ShapeDecoration(
                shape: const CircleBorder(),
                color: hasEdits
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.transparent,
              ),
              alignment: Alignment.center,
              child: !hasEdits
                  ? const Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: -2,
                          top: -3,
                          child: Icon(Icons.expand_more, size: 16),
                        ),
                      ],
                    )
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class WindowEffectSetter extends StatefulWidget {
  final WindowEffect effect;
  final bool enableEffects;
  final Widget child;

  const WindowEffectSetter({
    required this.effect,
    this.enableEffects = true,
    required this.child,
    super.key,
  });

  @override
  State<WindowEffectSetter> createState() => WindowEffectSetterState();
}

class WindowEffectSetterState extends State<WindowEffectSetter> {
  ThemeData? prevTheme;

  Future<void> _setEffect(WindowEffect effect, ThemeData theme) async {
    if (!widget.enableEffects) return;
    await Window.setEffect(
      effect: effect,
      color: theme.colorScheme.primary,
      dark: theme.brightness == Brightness.dark,
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    final theme = Theme.of(context);

    if (theme.brightness != prevTheme?.brightness) {
      _setEffect(widget.effect, theme);
      prevTheme = theme;
    }

    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant WindowEffectSetter old) {
    if (widget.effect != old.effect) {
      _setEffect(widget.effect, prevTheme!);
    }

    super.didUpdateWidget(old);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
