import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;

class AvatarBuilder {
  static Widget build(BuildContext context, fbs.Avatar model) {
    final id = model.id;
    final imageUrl = model.imageUrl;
    final fallbackLabel = model.fallbackLabel;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return FAvatar(
        key: id != null ? ValueKey(id) : null,
        image: NetworkImage(imageUrl),
        size: model.size,
        fallback: fallbackLabel != null ? Text(fallbackLabel) : null,
      );
    } else {
      return FAvatar.raw(
        key: id != null ? ValueKey(id) : null,
        size: model.size,
        child: fallbackLabel != null ? Center(child: Text(fallbackLabel)) : null,
      );
    }
  }
}
