import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:zeroflat/src/action_dispatcher.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;
import 'package:zeroflat/src/renderer.dart';

class ButtonBuilder {
  static Widget build(BuildContext context, fbs.Button model) {
    final id = model.id;
    return FButton(
      key: id != null ? ValueKey(id) : null,
      onPress: () => ZeroFlatActionDispatcher.dispatch(model.onPressType, model.onPress),
      variant: _mapVariant(model.variant),
      size: _mapSize(model.size),
      prefix: ZeroFlatRenderer.buildNode(context, model.prefixIconType, model.prefixIcon),
      suffix: ZeroFlatRenderer.buildNode(context, model.suffixIconType, model.suffixIcon),
      child: model.label != null 
          ? Text(model.label!) 
          : ZeroFlatRenderer.buildNode(context, model.childType, model.child),
    );
  }

  static FButtonVariant _mapVariant(fbs.ButtonVariant? v) {
    switch (v) {
      case fbs.ButtonVariant.Primary:
        return FButtonVariant.primary;
      case fbs.ButtonVariant.Secondary:
        return FButtonVariant.secondary;
      case fbs.ButtonVariant.Outline:
        return FButtonVariant.outline;
      case fbs.ButtonVariant.Destructive:
        return FButtonVariant.destructive;
      case fbs.ButtonVariant.Ghost:
        return FButtonVariant.ghost;
      default:
        return FButtonVariant.primary;
    }
  }

  static FButtonSizeVariant _mapSize(fbs.ButtonSize? s) {
    switch (s) {
      case fbs.ButtonSize.Xs:
        return FButtonSizeVariant.xs;
      case fbs.ButtonSize.Sm:
        return FButtonSizeVariant.sm;
      case fbs.ButtonSize.Md:
        return FButtonSizeVariant.md;
      case fbs.ButtonSize.Lg:
        return FButtonSizeVariant.lg;
      default:
        return FButtonSizeVariant.md;
    }
  }
}
