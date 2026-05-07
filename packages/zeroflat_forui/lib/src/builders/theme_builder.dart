import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;
import 'package:zeroflat/src/renderer.dart';
import 'package:zeroflat_forui/src/theme_registry.dart';

class ThemeBuilder {
  static Widget build(BuildContext context, fbs.Theme model) {
    final id = model.id;
    final themeData = ZeroFlatThemeRegistry.resolve(
      model.brightness,
      model.touch,
      borderRadius: model.borderRadius,
      borderWidth: model.borderWidth,
    );

    return FTheme(
      key: id != null ? ValueKey(id) : null,
      data: themeData,
      child: ZeroFlatRenderer.buildNode(context, model.childType, model.child),
    );
  }
}
