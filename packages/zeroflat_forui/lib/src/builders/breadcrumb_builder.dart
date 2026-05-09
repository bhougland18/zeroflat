import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:zeroflat/src/action_dispatcher.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;
import 'package:zeroflat/zeroflat.dart';

class BreadcrumbBuilder {
  static Widget build(BuildContext context, fbs.Breadcrumb model) {
    final id = model.id;

    final children = model.items
            ?.map((item) {
              final child = item.labelNode != null
                  ? ZeroFlatRenderer.buildNode(
                      context, item.labelNodeType, item.labelNode)
                  : Text(item.label ?? '');

              return FBreadcrumbItem(
                key: ValueKey(item.id),
                child: child,
                current: item.current,
                onPress: () => ZeroFlatActionDispatcher.dispatch(
                    item.onPressType, item.onPress,
                    context: context),
              );
            })
            .cast<Widget>()
            .toList() ??
        [];

    return FBreadcrumb(
      key: id != null ? ValueKey(id) : null,
      children: children,
    );
  }
}
