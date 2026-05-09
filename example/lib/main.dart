import 'package:flutter/widgets.dart';
import 'package:zeroflat/zeroflat.dart';
import 'package:zeroflat_forui/zeroflat_forui.dart';
import 'package:rinf/rinf.dart';

void main() async {
  // Initialize Rinf bridge
  await initializeRust(assignRustSignal);

  // Register Forui component builders
  ZeroFlatForui.register();

  runApp(const ZeroFlatExampleApp());
}

class ZeroFlatExampleApp extends StatelessWidget {
  const ZeroFlatExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'ZeroFlat Example',
      color: const Color(0xFF09090B),
      builder: (context, child) => Container(
        color: const Color(0xFF09090B), // Slate 950 (Shadcn default dark)
        child: const ZeroFlatRenderer(),
      ),
    );
  }
}
