import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:zeroflat/src/action_dispatcher.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;

class CheckboxBuilder {
  static Widget build(BuildContext context, fbs.Checkbox model) {
    final id = model.id;
    return _CheckboxWidget(model: model, key: id != null ? ValueKey(id) : null);
  }
}

class _CheckboxWidget extends StatefulWidget {
  final fbs.Checkbox model;
  const _CheckboxWidget({required this.model, super.key});

  @override
  State<_CheckboxWidget> createState() => _CheckboxWidgetState();
}

class _CheckboxWidgetState extends State<_CheckboxWidget> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.model.value ?? false;
  }

  @override
  void didUpdateWidget(covariant _CheckboxWidget old) {
    super.didUpdateWidget(old);
    if (widget.model.value != old.model.value) {
      setState(() => _value = widget.model.value ?? false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    return FCheckbox(
      value: _value,
      enabled: model.enabled ?? true,
      leadingLabel: model.leadingLabel ?? false,
      label: model.label != null ? Text(model.label!) : null,
      description: model.description != null ? Text(model.description!) : null,
      error: model.error != null ? Text(model.error!) : null,
      semanticsLabel: model.semanticLabel,
      onChange: (v) {
        setState(() => _value = v);
        ZeroFlatActionDispatcher.dispatch(model.onChangeType, model.onChange);
      },
    );
  }
}
