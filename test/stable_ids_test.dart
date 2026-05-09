import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;
import 'package:zeroflat/src/renderer.dart';
import 'package:zeroflat_forui/zeroflat_forui.dart';

// Renders a StacRoot FlatBuffer directly — no Rinf bridge needed in tests.
class _TestHost extends StatelessWidget {
  final List<int> bytes;
  const _TestHost({required this.bytes});

  @override
  Widget build(BuildContext context) {
    final root = fbs.StacRoot(bytes);
    return ZeroFlatRenderer.buildNode(context, root.nodeType, root.node);
  }
}

// Wraps _TestHost in the minimal tree Forui widgets require.
Widget _app(List<int> bytes) => MaterialApp(
      home: FTheme(
        data: FThemes.neutral.light.touch,
        child: _TestHost(bytes: bytes),
      ),
    );

void main() {
  setUpAll(() {
    ZeroFlatForui.register();
  });

  // ── Login screen ────────────────────────────────────────────────────────────

  testWidgets('login screen — all component ids are stable', (tester) async {
    final bytes = fbs.StacRootObjectBuilder(
      schemaVersion: 1,
      nodeType: fbs.StacNodeTypeId.Scaffold,
      node: fbs.ScaffoldObjectBuilder(
        id: 'login-scaffold',
        headerType: fbs.StacNodeTypeId.Header,
        header: fbs.HeaderObjectBuilder(id: 'login-header', title: 'Sign in'),
        contentType: fbs.StacNodeTypeId.Card,
        content: fbs.CardObjectBuilder(
          id: 'login-card',
          title: 'Welcome back',
          childType: fbs.StacNodeTypeId.TextField,
          child: fbs.TextFieldObjectBuilder(
            id: 'email-field',
            label: 'Email',
            hint: 'you@example.com',
          ),
        ),
        footerType: fbs.StacNodeTypeId.Button,
        footer: fbs.ButtonObjectBuilder(
          id: 'signin-btn',
          label: 'Sign in',
          variant: fbs.ButtonVariant.Primary,
        ),
      ),
    ).toBytes();

    await tester.pumpWidget(_app(bytes));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('login-scaffold')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-header')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('email-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('signin-btn')), findsOneWidget);
  });

  // ── Settings screen ─────────────────────────────────────────────────────────

  testWidgets('settings screen — all component ids are stable', (tester) async {
    final bytes = fbs.StacRootObjectBuilder(
      schemaVersion: 1,
      nodeType: fbs.StacNodeTypeId.Scaffold,
      node: fbs.ScaffoldObjectBuilder(
        id: 'settings-scaffold',
        headerType: fbs.StacNodeTypeId.Header,
        header: fbs.HeaderObjectBuilder(id: 'settings-header', title: 'Settings'),
        contentType: fbs.StacNodeTypeId.Card,
        content: fbs.CardObjectBuilder(
          id: 'settings-card',
          title: 'Preferences',
          subtitle: 'Adjust your preferences.',
          childType: fbs.StacNodeTypeId.Switch,
          child: fbs.SwitchObjectBuilder(
            id: 'notifications-switch',
            label: 'Notifications',
            description: 'Get pushes when peers sync.',
            value: true,
          ),
        ),
      ),
    ).toBytes();

    await tester.pumpWidget(_app(bytes));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings-scaffold')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-header')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('notifications-switch')), findsOneWidget);
  });

  // ── Re-render stability ─────────────────────────────────────────────────────
  // Pumping the same tree twice must produce the same keys (no re-keying on update).

  testWidgets('login screen — keys survive re-render', (tester) async {
    fbs.StacRootObjectBuilder loginTree({String emailLabel = 'Email'}) =>
        fbs.StacRootObjectBuilder(
          schemaVersion: 1,
          nodeType: fbs.StacNodeTypeId.Scaffold,
          node: fbs.ScaffoldObjectBuilder(
            id: 'login-scaffold',
            contentType: fbs.StacNodeTypeId.TextField,
            content: fbs.TextFieldObjectBuilder(
              id: 'email-field',
              label: emailLabel,
            ),
          ),
        );

    await tester.pumpWidget(_app(loginTree().toBytes()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('email-field')), findsOneWidget);

    // Simulate a server-driven update: same id, different label.
    await tester.pumpWidget(_app(loginTree(emailLabel: 'Email address').toBytes()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('email-field')), findsOneWidget);
  });
}
