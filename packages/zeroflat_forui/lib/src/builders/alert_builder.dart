import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;
import 'package:zeroflat/src/renderer.dart';

class AlertBuilder {
  static Widget build(BuildContext context, fbs.Alert model) {
    final id = model.id;

    final Widget titleWidget;
    final titleNode = model.titleNode;
    if (titleNode != null) {
      titleWidget = ZeroFlatRenderer.buildNode(
          context, model.titleNodeType, titleNode);
    } else {
      titleWidget = Text(model.title ?? '');
    }

    final subtitleNode = model.subtitleNode;
    final Widget? subtitleWidget = subtitleNode != null
        ? ZeroFlatRenderer.buildNode(
            context, model.subtitleNodeType, subtitleNode)
        : model.subtitle != null
            ? Text(model.subtitle!)
            : null;

    final iconNode = model.icon;
    final Widget? iconWidget = iconNode != null
        ? ZeroFlatRenderer.buildNode(context, model.iconType, iconNode)
        : null;

    return FAlert(
      key: id != null ? ValueKey(id) : null,
      variant: _mapVariant(model.variant),
      title: titleWidget,
      subtitle: subtitleWidget,
      icon: iconWidget ?? const Icon(FIcons.circleAlert),
    );
  }

  static FAlertVariant _mapVariant(fbs.AlertVariant? v) {
    switch (v) {
      case fbs.AlertVariant.Primary:
        return FAlertVariant.primary;
      case fbs.AlertVariant.Destructive:
        return FAlertVariant.destructive;
      default:
        return FAlertVariant.primary;
    }
  }
}
