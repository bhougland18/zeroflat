import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:zeroflat/src/action_dispatcher.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;
import 'package:zeroflat/zeroflat.dart';

class SelectGroupBuilder {
  static Widget build(BuildContext context, fbs.SelectGroup model) {
    final id = model.id;

    final children = model.items
            ?.map((item) {
              final label = item.labelNode != null
                  ? ZeroFlatRenderer.buildNode(
                      context, item.labelNodeType, item.labelNode)
                  : Text(item.label ?? '');

              final description =
                  item.description != null ? Text(item.description!) : null;

              if (model.variant == fbs.SelectGroupVariant.Checkbox) {
                return FSelectGroupItemMixin.checkbox<String>(
                  value: item.value ?? '',
                  label: label,
                  description: description,
                );
              } else {
                return FSelectGroupItemMixin.radio<String>(
                  value: item.value ?? '',
                  label: label,
                  description: description,
                );
              }
            })
            .cast<FSelectGroupItemMixin<String>>()
            .toList() ??
        [];

    final selectedValues = model.values?.cast<String>().toSet() ?? {};

    return FSelectGroup<String>(
      key: id != null ? ValueKey(id) : null,
      label: model.label != null ? Text(model.label!) : null,
      description: model.description != null ? Text(model.description!) : null,
      children: children,
      control: FMultiValueControl.managed(
        initial: selectedValues,
        onChange: (values) {
          final action = model.onChange;
          if (action != null) {
            ZeroFlatActionDispatcher.dispatch(model.onChangeType, action,
                context: context);
          }
        },
      ),
    );
  }
}
