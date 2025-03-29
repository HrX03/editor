import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:re_editor/re_editor.dart';

class LineHighlightLayer extends SingleChildRenderObjectWidget {
  final CodeLineEditingController controller;
  final CodeIndicatorValueNotifier notifier;
  final bool enableLineHighlighting;
  final Color color;

  const LineHighlightLayer({
    required this.controller,
    required this.notifier,
    required this.enableLineHighlighting,
    required this.color,
    required super.child,
    super.key,
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
