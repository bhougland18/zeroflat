import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:zeroflat/src/action_dispatcher.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;
import 'package:zeroflat/src/renderer.dart';

class TextFieldBuilder {
  static Widget build(BuildContext context, fbs.TextField model) {
    final id = model.id;

    // Initial text is set once per component identity (ValueKey(id)).
    // After first render local edits take over; FTextFieldControl.managed
    // preserves the controller across UiUpdates as long as the key is stable.
    final initial = model.value != null
        ? TextEditingValue(text: model.value!)
        : null;

    return FTextField(
      key: id != null ? ValueKey(id) : null,
      control: FTextFieldControl.managed(
        initial: initial,
        onChange: id != null && model.onChangeType != null
            ? (val) => ZeroFlatActionDispatcher.dispatchTextField(
                  type: model.onChangeType,
                  action: model.onChange,
                  text: val.text,
                  debounceId: id,
                )
            : null,
      ),
      label: model.label != null ? Text(model.label!) : null,
      hint: model.hint,
      description: model.description != null ? Text(model.description!) : null,
      error: model.error != null ? Text(model.error!) : null,
      obscureText: model.obscureText ?? false,
      onSubmit: model.onSubmitType != null
          ? (_) => ZeroFlatActionDispatcher.dispatch(model.onSubmitType, model.onSubmit)
          : null,
      prefixBuilder: model.prefixType != null
          ? (ctx, _, __) => ZeroFlatRenderer.buildNode(ctx, model.prefixType, model.prefix)
          : null,
      suffixBuilder: model.suffixType != null
          ? (ctx, _, __) => ZeroFlatRenderer.buildNode(ctx, model.suffixType, model.suffix)
          : null,
    );
  }
}
