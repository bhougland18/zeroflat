import 'package:zeroflat/src/action_dispatcher.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;
import 'package:zeroflat/src/renderer.dart';
import 'package:zeroflat_forui/src/builders/button_builder.dart';
import 'package:zeroflat_forui/src/builders/card_builder.dart';
import 'package:zeroflat_forui/src/builders/checkbox_builder.dart';
import 'package:zeroflat_forui/src/builders/dialog_builder.dart';
import 'package:zeroflat_forui/src/builders/divider_builder.dart';
import 'package:zeroflat_forui/src/builders/header_builder.dart';
import 'package:zeroflat_forui/src/builders/scaffold_builder.dart';
import 'package:zeroflat_forui/src/builders/switch_builder.dart';
import 'package:zeroflat_forui/src/builders/text_field_builder.dart';
import 'package:zeroflat_forui/src/builders/theme_builder.dart';
import 'package:zeroflat_forui/src/overlays.dart';

/// Registers the complete set of Forui component builders into [ZeroFlatRenderer]
/// and wires the Forui overlay handler into [ZeroFlatActionDispatcher].
///
/// Call once at app startup before mounting [ZeroFlatRenderer]:
/// ```dart
/// ZeroFlatForui.register();
/// runApp(const MyApp());
/// ```
class ZeroFlatForui {
  static void register() {
    ZeroFlatRenderer.register(fbs.StacNodeTypeId.Theme,
        (ctx, m) => ThemeBuilder.build(ctx, m as fbs.Theme));
    ZeroFlatRenderer.register(fbs.StacNodeTypeId.Scaffold,
        (ctx, m) => ScaffoldBuilder.build(ctx, m as fbs.Scaffold));
    ZeroFlatRenderer.register(fbs.StacNodeTypeId.Header,
        (ctx, m) => HeaderBuilder.build(ctx, m as fbs.Header));
    ZeroFlatRenderer.register(fbs.StacNodeTypeId.Divider,
        (ctx, m) => DividerBuilder.build(ctx, m as fbs.Divider));
    ZeroFlatRenderer.register(fbs.StacNodeTypeId.Button,
        (ctx, m) => ButtonBuilder.build(ctx, m as fbs.Button));
    ZeroFlatRenderer.register(fbs.StacNodeTypeId.TextField,
        (ctx, m) => TextFieldBuilder.build(ctx, m as fbs.TextField));
    ZeroFlatRenderer.register(fbs.StacNodeTypeId.Switch,
        (ctx, m) => SwitchBuilder.build(ctx, m as fbs.Switch));
    ZeroFlatRenderer.register(fbs.StacNodeTypeId.Checkbox,
        (ctx, m) => CheckboxBuilder.build(ctx, m as fbs.Checkbox));
    ZeroFlatRenderer.register(fbs.StacNodeTypeId.Card,
        (ctx, m) => CardBuilder.build(ctx, m as fbs.Card));
    ZeroFlatRenderer.register(fbs.StacNodeTypeId.Dialog,
        (ctx, m) => DialogBuilder.build(ctx, m as fbs.Dialog));

    ZeroFlatActionDispatcher.setOverlayHandler(ForuiOverlayHandler.handle);
  }
}
