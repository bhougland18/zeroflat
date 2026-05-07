import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;
import 'package:zeroflat/src/renderer.dart';

class HeaderBuilder {
  static Widget build(BuildContext context, fbs.Header model) {
    final id = model.id;

    final title = model.titleNodeType != null
        ? ZeroFlatRenderer.buildNode(context, model.titleNodeType, model.titleNode)
        : model.title != null ? Text(model.title!) : const SizedBox.shrink();

    // Combine suffixes and actions into FHeader's single trailing list.
    final trailing = [
      ...?model.suffixes?.map((s) => ZeroFlatRenderer.buildNodeSlot(context, s)),
      ...?model.actions?.map((a) => ZeroFlatRenderer.buildNodeSlot(context, a)),
    ];

    return FHeader(
      key: id != null ? ValueKey(id) : null,
      title: title,
      suffixes: trailing,
    );
  }
}
