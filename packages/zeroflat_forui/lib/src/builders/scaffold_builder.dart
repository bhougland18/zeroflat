import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;
import 'package:zeroflat/src/renderer.dart';

class ScaffoldBuilder {
  static Widget build(BuildContext context, fbs.Scaffold model) {
    final id = model.id;
    return FScaffold(
      key: id != null ? ValueKey(id) : null,
      header: ZeroFlatRenderer.buildNodeOrNull(context, model.headerType, model.header),
      footer: ZeroFlatRenderer.buildNodeOrNull(context, model.footerType, model.footer),
      child: ZeroFlatRenderer.buildNode(context, model.contentType, model.content),
    );
  }
}
