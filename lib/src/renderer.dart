import 'package:flutter/widgets.dart';
import 'package:zeroflat/src/bindings/bindings.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;

/// A function that builds a widget from a FlatBuffer component model.
typedef ZeroFlatNodeBuilder = Widget Function(BuildContext context, dynamic model);

/// The central entry point for the ZeroFlat stateless UI renderer.
///
/// This engine is "dumb": it handles the Rinf signal loop and dispatches
/// decoding, but it has no built-in knowledge of specific UI components.
///
/// To use it, you must register builders for each component type:
///
/// ```dart
/// ZeroFlatRenderer.register(fbs.StacNodeTypeId.Button, (context, model) => MyButton(model));
/// ```
class ZeroFlatRenderer extends StatelessWidget {
  static final Map<fbs.StacNodeTypeId, ZeroFlatNodeBuilder> _builders = {};

  const ZeroFlatRenderer({super.key});

  /// Registers a builder for a specific [fbs.StacNodeTypeId].
  static void register(fbs.StacNodeTypeId type, ZeroFlatNodeBuilder builder) {
    _builders[type] = builder;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: UiUpdate.rustSignalStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final signalPack = snapshot.data!;
        final binary = signalPack.binary;

        if (binary.isEmpty) {
          return const SizedBox.shrink();
        }

        // Decode the StacRoot from the binary payload.
        final root = fbs.StacRoot(binary);
        
        return buildNode(context, root.nodeType, root.node);
      }
    );
  }

  /// Recursively builds a widget from a [fbs.StacNode] union.
  ///
  /// This dispatcher lookups the registered builder for the given [type].
  static Widget buildNode(BuildContext context, fbs.StacNodeTypeId? type, dynamic node) {
    if (type == null || node == null) {
      return const SizedBox.shrink();
    }

    final builder = _builders[type];
    if (builder == null) {
      // If no builder is registered, we can't render the node.
      return const SizedBox.shrink();
    }

    return builder(context, node);
  }

  /// Builds a widget from a [fbs.NodeSlot].
  static Widget buildNodeSlot(BuildContext context, fbs.NodeSlot? slot) {
    if (slot == null) return const SizedBox.shrink();
    return buildNode(context, slot.nodeType, slot.node);
  }

  /// Like [buildNode] but returns null when the slot is absent.
  /// Use this for Widget? parameters (e.g. FScaffold.header/footer) so the
  /// parent widget can distinguish "no slot" from "empty widget".
  static Widget? buildNodeOrNull(BuildContext context, fbs.StacNodeTypeId? type, dynamic node) {
    if (type == null || node == null) return null;
    return _builders[type]?.call(context, node);
  }
}
