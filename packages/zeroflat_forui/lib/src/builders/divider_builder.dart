import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:zeroflat_forui/src/builders/color_token.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;

class DividerBuilder {
  static Widget build(BuildContext context, fbs.Divider model) {
    final id = model.id;
    final axis = model.axis == fbs.Axis.Vertical ? Axis.vertical : Axis.horizontal;
    final color = model.color.resolve(context);
    final thickness = model.thickness ?? 1.0;
    final p = model.padding;
    final padding = p != null
        ? EdgeInsetsDirectional.fromSTEB(p.left ?? 0, p.top ?? 0, p.right ?? 0, p.bottom ?? 0)
        : null;

    return FDivider(
      key: id != null ? ValueKey(id) : null,
      axis: axis,
      style: FDividerStyleDelta.delta(
        color: color,
        width: thickness,
        padding: padding != null ? EdgeInsetsGeometryDelta.value(padding) : null,
      ),
    );
  }
}
