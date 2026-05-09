import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;
import 'package:zeroflat/zeroflat.dart';

class DialogBuilder {
  static Widget build(BuildContext context, fbs.Dialog model) {
    final id = model.id;

    final actions = model.actions
            ?.map((slot) => ZeroFlatRenderer.buildNodeSlot(context, slot))
            .toList() ??
        [];

    final title = model.titleNodeType != null
        ? ZeroFlatRenderer.buildNode(context, model.titleNodeType, model.titleNode)
        : model.title != null ? Text(model.title!) : null;

    final body = model.bodyNodeType != null
        ? ZeroFlatRenderer.buildNode(context, model.bodyNodeType, model.bodyNode)
        : model.body != null ? Text(model.body!) : null;

    final direction = model.axis == fbs.Axis.Horizontal ? Axis.horizontal : Axis.vertical;

    return FDialog(
      key: id != null ? ValueKey(id) : null,
      actions: actions,
      title: title,
      body: body,
      direction: direction,
    );
  }
}
