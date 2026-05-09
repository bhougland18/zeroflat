import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:zeroflat/src/action_dispatcher.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;

class SliderBuilder {
  static Widget build(BuildContext context, fbs.Slider model) {
    final id = model.id;

    return FSlider(
      key: id != null ? ValueKey(id) : null,
      label: model.label != null ? Text(model.label!) : null,
      description: model.description != null ? Text(model.description!) : null,
      control: FSliderControl.managedContinuous(
        initial: FSliderValue(max: model.value),
        onChange: (value) {
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
