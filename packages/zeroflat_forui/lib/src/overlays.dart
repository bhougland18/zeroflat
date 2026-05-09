import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;
import 'package:zeroflat/src/renderer.dart';
import 'package:zeroflat_forui/src/builders/dialog_builder.dart';

/// Handles overlay actions (ActionShowDialog / ActionShowSheet / ActionShowToast)
/// using Forui's presentation APIs.
///
/// Registered into [ZeroFlatActionDispatcher] by [ZeroFlatForui.register].
class ForuiOverlayHandler {
  static Future<void> handle(
    BuildContext context,
    fbs.StacActionTypeId type,
    dynamic action,
  ) async {
    switch (type) {
      case fbs.StacActionTypeId.ActionShowDialog:
        await _showDialog(context, action as fbs.ActionShowDialog);
      case fbs.StacActionTypeId.ActionShowToast:
        _showToast(context, action as fbs.ActionShowToast);
      case fbs.StacActionTypeId.ActionShowSheet:
        // Sheet routing — future work.
        break;
      default:
        break;
    }
  }

  static Future<void> _showDialog(
    BuildContext context,
    fbs.ActionShowDialog action,
  ) async {
    final bytes = action.dialogFbs;
    if (bytes == null) return;

    final root = fbs.StacRoot(bytes);
    if (root.nodeType != fbs.StacNodeTypeId.Dialog) return;
    final model = root.node as fbs.Dialog;

    if (!context.mounted) return;
    await showFDialog(
      context: context,
      builder: (ctx, style, animation) => DialogBuilder.build(ctx, model),
    );
  }

  static void _showToast(BuildContext context, fbs.ActionShowToast action) {
    final toast = action.toast;
    if (toast == null) return;

    final variant = toast.variant == fbs.ToastVariant.Destructive
        ? FToastVariant.destructive
        : FToastVariant.primary;

    showFToast(
      context: context,
      variant: variant,
      title: Text(toast.title ?? ''),
      description: toast.description != null ? Text(toast.description!) : null,
    );
  }
}
