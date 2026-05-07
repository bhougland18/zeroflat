import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;
import 'package:zeroflat/src/renderer.dart';

class CardBuilder {
  static Widget build(BuildContext context, fbs.Card model) {
    final id = model.id;

    final title = model.titleNodeType != null
        ? ZeroFlatRenderer.buildNode(context, model.titleNodeType, model.titleNode)
        : model.title != null ? Text(model.title!) : null;

    final subtitle = model.subtitleNodeType != null
        ? ZeroFlatRenderer.buildNode(context, model.subtitleNodeType, model.subtitleNode)
        : model.subtitle != null ? Text(model.subtitle!) : null;

    final child = ZeroFlatRenderer.buildNodeOrNull(context, model.childType, model.child);

    return FCard(
      key: id != null ? ValueKey(id) : null,
      title: title,
      subtitle: subtitle,
      child: child,
    );
  }
}
