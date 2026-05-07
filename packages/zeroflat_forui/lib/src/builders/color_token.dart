import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;

extension ColorTokenResolver on fbs.ColorToken? {
  Color resolve(BuildContext context) {
    final c = context.theme.colors;
    return switch (this) {
      fbs.ColorToken.Primary             => c.primary,
      fbs.ColorToken.PrimaryForeground   => c.primaryForeground,
      fbs.ColorToken.Secondary           => c.secondary,
      fbs.ColorToken.SecondaryForeground => c.secondaryForeground,
      fbs.ColorToken.Muted               => c.muted,
      fbs.ColorToken.MutedForeground     => c.mutedForeground,
      fbs.ColorToken.Destructive         => c.destructive,
      fbs.ColorToken.DestructiveForeground => c.destructiveForeground,
      fbs.ColorToken.Error               => c.error,
      fbs.ColorToken.ErrorForeground     => c.errorForeground,
      fbs.ColorToken.Background          => c.background,
      fbs.ColorToken.Foreground          => c.foreground,
      fbs.ColorToken.Card                => c.card,
      fbs.ColorToken.Border              => c.border,
      fbs.ColorToken.Barrier             => c.barrier,
      _                                  => c.border,
    };
  }
}
