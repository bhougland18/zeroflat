import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:zeroflat/src/action_dispatcher.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;
import 'package:zeroflat/zeroflat.dart';

class TabsBuilder {
  static Widget build(BuildContext context, fbs.Tabs model) {
    final id = model.id;

    final children = model.tabs
            ?.map((tab) => FTabEntry(
                  label: tab.labelNode != null
                      ? ZeroFlatRenderer.buildNode(
                          context, tab.labelNodeType, tab.labelNode)
                      : Text(tab.label ?? ''),
                  child: ZeroFlatRenderer.buildNode(
                      context, tab.contentType, tab.content),
                ))
            .toList() ??
        [];

    if (children.isEmpty) return const SizedBox.shrink();

    return FTabs(
      key: id != null ? ValueKey(id) : null,
      children: children,
      control: FTabControl.managed(
        initial: model.initialIndex,
        onChange: (index) {
          final action = model.onChange;
          if (action != null) {
            // We might want a specialized dispatch for index changes
            // but for now we just fire the action.
            ZeroFlatActionDispatcher.dispatch(model.onChangeType, action,
                context: context);
          }
        },
      ),
    );
  }
}
