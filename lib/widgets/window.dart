import 'dart:math';

import 'package:editor/internal/environment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:responsive_framework/responsive_framework.dart';
import 'package:window_manager/window_manager.dart';

class WindowBar extends StatefulWidget implements PreferredSizeWidget {
  final Widget? leading;
  final Widget? title;

  const WindowBar({this.leading, this.title, super.key});

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
    final isFull = ResponsiveBreakpoints.of(context).largerThan('COMPACT');

    return Stack(
      fit: StackFit.expand,
      children: [
        const DragToMoveArea(child: SizedBox.expand()),
        Positioned.fill(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.leading != null) SizedBox(height: double.infinity, child: widget.leading),
              if (isFull)
                const Spacer()
              else if (widget.title != null)
                Expanded(
                  child: SizedBox.expand(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Align(alignment: Alignment.centerLeft, child: widget.title),
                    ),
                  ),
                ),
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
                      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
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
        ),
        if (widget.title != null && isFull) Positioned.fill(child: Center(child: widget.title)),
      ],
    );
  }
}

class WindowTitle extends ConsumerWidget {
  const WindowTitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(editorEnvironmentProvider.select((value) => value.value!.file));
    final textController = ref.watch(editorControllerProvider);
    final hasEdits = ref.watch(hasEditsProvider);

    final firstLine = textController.codeLines.first.text;

    String fileName = firstLine.substring(0, min(firstLine.length, 40)).trim();
    fileName = fileName.isNotEmpty ? fileName : "Untitled";

    return IgnorePointer(
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: file != null ? p.basename(file.path) : fileName),
            if (hasEdits)
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: ShapeDecoration(
                    shape: const CircleBorder(),
                    color: hasEdits ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                  ),
                ),
              ),
          ],
        ),
        overflow: TextOverflow.ellipsis,
      ),
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
    //if (!widget.enableEffects) return;
    await Window.setEffect(
      effect: widget.enableEffects ? effect : WindowEffect.disabled,
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
