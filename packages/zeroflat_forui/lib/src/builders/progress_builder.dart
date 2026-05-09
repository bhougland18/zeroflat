import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;

class ProgressBuilder {
  static Widget build(BuildContext context, fbs.Progress model) {
    final id = model.id;
    final value = model.value;

    if (value >= 0.0 && value <= 1.0) {
      return FDeterminateProgress(
        key: id != null ? ValueKey(id) : null,
        value: value,
        semanticsLabel: model.label,
      );
    } else {
      return FProgress(
        key: id != null ? ValueKey(id) : null,
        semanticsLabel: model.label,
      );
    }
  }
}
