import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;
import 'package:zeroflat/zeroflat.dart';

class AccordionBuilder {
  static Widget build(BuildContext context, fbs.Accordion model) {
    final id = model.id;

    final children = model.items
            ?.map((item) {
              final Widget title = item.titleNode != null
                  ? ZeroFlatRenderer.buildNode(
                      context, item.titleNodeType, item.titleNode)
                  : Text(item.title ?? '');

              final Widget child = ZeroFlatRenderer.buildNode(
                  context, item.contentType, item.content);

              final Widget? icon = item.icon != null
                  ? ZeroFlatRenderer.buildNode(
                      context, item.iconType, item.icon)
                  : null;

              return FAccordionItem(
                key: ValueKey(item.id),
                title: title,
                child: child,
                icon: icon ?? const Icon(FIcons.chevronDown),
                initiallyExpanded: item.initiallyExpanded,
              );
            })
            .toList() ??
        [];

    return FAccordion(
      key: id != null ? ValueKey(id) : null,
      children: children,
    );
  }
}
