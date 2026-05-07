import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:zeroflat/src/action_dispatcher.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;

class SwitchBuilder {
  static Widget build(BuildContext context, fbs.Switch model) =>
      _SwitchWidget(model: model, key: model.id != null ? ValueKey(model.id) : null);
}

class _SwitchWidget extends StatefulWidget {
  final fbs.Switch model;
  const _SwitchWidget({required this.model, super.key});

  @override
  State<_SwitchWidget> createState() => _SwitchWidgetState();
}

class _SwitchWidgetState extends State<_SwitchWidget> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.model.value ?? false;
  }

  @override
  void didUpdateWidget(covariant _SwitchWidget old) {
    super.didUpdateWidget(old);
    // Accept server-driven value changes; ignore if unchanged (preserves optimistic toggle).
    if (widget.model.value != old.model.value) {
      setState(() => _value = widget.model.value ?? false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    return FSwitch(
      value: _value,
      enabled: model.enabled ?? true,
      leadingLabel: false,
      label: model.label != null ? Text(model.label!) : null,
      description: model.description != null ? Text(model.description!) : null,
      semanticsLabel: model.semanticLabel,
      onChange: (v) {
        setState(() => _value = v);
        ZeroFlatActionDispatcher.dispatch(model.onChangeType, model.onChange);
      },
    );
  }
}
