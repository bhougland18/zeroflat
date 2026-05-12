import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:zeroflat/src/action_dispatcher.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;
import 'package:zeroflat/src/renderer.dart';

class FlowBuilder {
  static Widget build(BuildContext context, fbs.Flow model) {
    final id = model.id;
    return _FlowWidget(model: model, key: id != null ? ValueKey(id) : null);
  }
}

class _FlowWidget extends StatefulWidget {
  final fbs.Flow model;
  const _FlowWidget({required this.model, super.key});

  @override
  State<_FlowWidget> createState() => _FlowWidgetState();
}

class _FlowWidgetState extends State<_FlowWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late bool _open;

  @override
  void initState() {
    super.initState();
    _open = widget.model.open;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: _open ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(covariant _FlowWidget old) {
    super.didUpdateWidget(old);
    // Accept server-driven open state changes.
    if (widget.model.open != old.model.open) {
      _setOpen(widget.model.open, dispatch: false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setOpen(bool value, {bool dispatch = true}) {
    setState(() => _open = value);
    if (value) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    if (dispatch) {
      ZeroFlatActionDispatcher.dispatch(
        widget.model.onToggleType,
        widget.model.onToggle,
      );
    }
  }

  void _onTriggerTap() => _setOpen(!_open);

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final trigger = ZeroFlatRenderer.buildNodeOrNull(
      context,
      model.triggerType,
      model.trigger,
    );

    final childWidgets = <Widget>[
      // Trigger is always child 0 — delegates reference it by index.
      GestureDetector(onTap: _onTriggerTap, child: trigger ?? const SizedBox()),
      ...List.generate(
        model.children?.length ?? 0,
        (i) => ZeroFlatRenderer.buildNodeSlot(context, model.children![i]),
      ),
    ];

    final FlowDelegate delegate = switch (model.delegate) {
      fbs.FlowDelegateType.SpeedDial => _SpeedDialDelegate(
          animation: _controller,
          itemCount: childWidgets.length - 1,
          axis: model.axis == fbs.Axis.Horizontal
              ? Axis.horizontal
              : Axis.vertical,
          spacing: model.spacing,
        ),
      _ => _RadialMenuDelegate(
          animation: _controller,
          itemCount: childWidgets.length - 1,
          radius: model.radius,
          angleStartDeg: model.angleStart,
          angleSweepDeg: model.angleSweep,
        ),
    };

    return Flow(delegate: delegate, children: childWidgets);
  }
}

// ── RadialMenu delegate ───────────────────────────────────────────────────────

class _RadialMenuDelegate extends FlowDelegate {
  final Animation<double> animation;
  final int itemCount;
  final double radius;
  final double angleStartDeg;
  final double angleSweepDeg;

  const _RadialMenuDelegate({
    required this.animation,
    required this.itemCount,
    required this.radius,
    required this.angleStartDeg,
    required this.angleSweepDeg,
  }) : super(repaint: animation);

  @override
  void paintChildren(FlowPaintingContext context) {
    final triggerSize = context.getChildSize(0) ?? Size.zero;
    final cx = triggerSize.width / 2;
    final cy = triggerSize.height / 2;

    // Paint trigger (child 0) at origin.
    context.paintChild(0, transform: Matrix4.identity());

    if (itemCount == 0) return;

    final double step =
        itemCount > 1 ? angleSweepDeg / (itemCount - 1) : 0.0;

    for (int i = 0; i < itemCount; i++) {
      final int childIndex = i + 1;
      final childSize = context.getChildSize(childIndex) ?? Size.zero;

      final double angleDeg = angleStartDeg + step * i;
      final double rad = angleDeg * math.pi / 180.0;

      final double t = animation.value;
      final double r = radius * t;

      final double dx = cx + r * math.cos(rad) - childSize.width / 2;
      final double dy = cy + r * math.sin(rad) - childSize.height / 2;

      context.paintChild(
        childIndex,
        transform: Matrix4.translationValues(dx, dy, 0)
          ..scaleByDouble(t, t, 1.0, 1.0),
        opacity: t,
      );
    }
  }

  @override
  Size getSize(BoxConstraints constraints) =>
      Size(constraints.maxWidth, constraints.maxHeight);

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      const BoxConstraints();

  @override
  bool shouldRepaint(_RadialMenuDelegate old) =>
      old.radius != radius ||
      old.angleStartDeg != angleStartDeg ||
      old.angleSweepDeg != angleSweepDeg ||
      old.itemCount != itemCount;
}

// ── SpeedDial delegate ────────────────────────────────────────────────────────

class _SpeedDialDelegate extends FlowDelegate {
  final Animation<double> animation;
  final int itemCount;
  final Axis axis;
  final double spacing;

  const _SpeedDialDelegate({
    required this.animation,
    required this.itemCount,
    required this.axis,
    required this.spacing,
  }) : super(repaint: animation);

  @override
  void paintChildren(FlowPaintingContext context) {
    final triggerSize = context.getChildSize(0) ?? Size.zero;

    // Paint trigger at origin.
    context.paintChild(0, transform: Matrix4.identity());

    double offset = axis == Axis.vertical
        ? triggerSize.height + spacing
        : triggerSize.width + spacing;

    final double t = animation.value;

    for (int i = 0; i < itemCount; i++) {
      final int childIndex = i + 1;
      final childSize = context.getChildSize(childIndex) ?? Size.zero;

      final double animatedOffset = offset * t;

      final double dx = axis == Axis.horizontal ? animatedOffset : 0;
      final double dy = axis == Axis.vertical ? -animatedOffset : 0;

      context.paintChild(
        childIndex,
        transform: Matrix4.translationValues(dx, dy, 0),
        opacity: t,
      );

      offset += (axis == Axis.vertical
              ? childSize.height
              : childSize.width) +
          spacing;
    }
  }

  @override
  Size getSize(BoxConstraints constraints) =>
      Size(constraints.maxWidth, constraints.maxHeight);

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      const BoxConstraints();

  @override
  bool shouldRepaint(_SpeedDialDelegate old) =>
      old.axis != axis ||
      old.spacing != spacing ||
      old.itemCount != itemCount;
}
