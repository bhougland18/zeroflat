import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:zeroflat/src/bindings/bindings.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;

/// The central dispatcher for user interactions.
///
/// Wraps [fbs.StacAction] signals in a [fbs.UiActionEnvelope] and sends them
/// to Rust via the [UiAction] Rinf binary signal.
///
/// Overlay actions (ActionShowDialog / ActionShowSheet / ActionShowToast)
/// require a UI-framework-specific handler. Register one via
/// [setOverlayHandler] — typically called from the component library
/// (e.g. ZeroFlatForui.register()) at app startup.
class ZeroFlatActionDispatcher {
  // Per-component debounce timers, keyed by component id.
  static final Map<String, Timer> _debounceTimers = {};

  // Injected by the component library (e.g. zeroflat_forui) at startup.
  static Future<void> Function(BuildContext, fbs.StacActionTypeId, dynamic)?
      _overlayHandler;

  /// Registers a handler for overlay actions (Dialog / Sheet / Toast).
  ///
  /// The handler receives the BuildContext from the triggering widget and is
  /// responsible for presenting the appropriate overlay using whatever UI
  /// framework is in use.
  static void setOverlayHandler(
    Future<void> Function(BuildContext, fbs.StacActionTypeId, dynamic) handler,
  ) {
    _overlayHandler = handler;
  }

  /// Dispatches a [fbs.StacAction] union.
  ///
  /// Pass [context] for overlay actions so the registered [_overlayHandler]
  /// can present the appropriate UI.
  static void dispatch(
    fbs.StacActionTypeId? type,
    dynamic action, {
    BuildContext? context,
  }) {
    if (type == null || action == null) return;

    if (context != null && _overlayHandler != null) {
      switch (type) {
        case fbs.StacActionTypeId.ActionShowDialog:
        case fbs.StacActionTypeId.ActionShowSheet:
        case fbs.StacActionTypeId.ActionShowToast:
          _overlayHandler!(context, type, action);
          return;
        default:
          break;
      }
    }

    final builder = _createBuilder(type, action);
    if (builder == null) return;
    _send(type, builder);
  }

  /// Variant for TextField onChange: injects [text] as the value into an
  /// [fbs.ActionUpdateState] before dispatching. Debounced per [debounceId].
  static void dispatchTextField({
    required fbs.StacActionTypeId? type,
    required dynamic action,
    required String text,
    required String debounceId,
    Duration debounceDuration = const Duration(milliseconds: 300),
  }) {
    if (type == null || action == null) return;

    _debounceTimers[debounceId]?.cancel();
    _debounceTimers[debounceId] = Timer(debounceDuration, () {
      _debounceTimers.remove(debounceId);
      if (type == fbs.StacActionTypeId.ActionUpdateState) {
        final a = action as fbs.ActionUpdateState;
        _send(type, fbs.ActionUpdateStateObjectBuilder(key: a.key, value: text));
      } else {
        dispatch(type, action);
      }
    });
  }

  static void _send(fbs.StacActionTypeId type, Object builder) {
    final envelope =
        fbs.UiActionEnvelopeObjectBuilder(actionType: type, action: builder);
    UiAction().sendSignalToRust(envelope.toBytes());
  }

  static Object? _createBuilder(fbs.StacActionTypeId type, dynamic action) {
    switch (type) {
      case fbs.StacActionTypeId.ActionUpdateState:
        final a = action as fbs.ActionUpdateState;
        return fbs.ActionUpdateStateObjectBuilder(key: a.key, value: a.value);
      case fbs.StacActionTypeId.ActionNavigate:
        final a = action as fbs.ActionNavigate;
        return fbs.ActionNavigateObjectBuilder(route: a.route, args: a.args);
      case fbs.StacActionTypeId.ActionCustom:
        final a = action as fbs.ActionCustom;
        return fbs.ActionCustomObjectBuilder(name: a.name, payload: a.payload);
      case fbs.StacActionTypeId.ActionShowDialog:
        final a = action as fbs.ActionShowDialog;
        return fbs.ActionShowDialogObjectBuilder(dialogFbs: a.dialogFbs);
      case fbs.StacActionTypeId.ActionShowSheet:
        final a = action as fbs.ActionShowSheet;
        return fbs.ActionShowSheetObjectBuilder(side: a.side, sheetFbs: a.sheetFbs);
      case fbs.StacActionTypeId.ActionShowToast:
        final a = action as fbs.ActionShowToast;
        return fbs.ActionShowToastObjectBuilder(
          toast: fbs.ToastConfigObjectBuilder(
            title: a.toast?.title,
            description: a.toast?.description,
            variant: a.toast?.variant,
          ),
        );
      case fbs.StacActionTypeId.NONE:
        return null;
    }
  }
}
