import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;
import 'package:zeroflat/zeroflat.dart';

class BadgeBuilder {
  static Widget build(BuildContext context, fbs.Badge model) {
    final id = model.id;

    return FBadge(
      key: id != null ? ValueKey(id) : null,
      variant: _mapVariant(model.variant),
      child: model.label != null
          ? Text(model.label!)
          : ZeroFlatRenderer.buildNode(context, model.childType, model.child),
    );
  }

  static FBadgeVariant _mapVariant(fbs.BadgeVariant? v) {
    switch (v) {
      case fbs.BadgeVariant.Primary:
        return FBadgeVariant.primary;
      case fbs.BadgeVariant.Secondary:
        return FBadgeVariant.secondary;
      case fbs.BadgeVariant.Outline:
        return FBadgeVariant.outline;
      case fbs.BadgeVariant.Destructive:
        return FBadgeVariant.destructive;
      default:
        return FBadgeVariant.primary;
    }
  }
}
