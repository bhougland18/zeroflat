import 'package:forui/forui.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;

typedef FThemePalette = ({FPlatformThemeData dark, FPlatformThemeData light});

class ZeroFlatThemeRegistry {
  static final Map<String, FThemePalette> _palettes = {
    'neutral': FThemes.neutral,
    'zinc': FThemes.zinc,
    'slate': FThemes.slate,
    'blue': FThemes.blue,
    'green': FThemes.green,
    'orange': FThemes.orange,
    'red': FThemes.red,
    'rose': FThemes.rose,
    'violet': FThemes.violet,
    'yellow': FThemes.yellow,
  };

  static String _activePalette = 'neutral';

  static void setPalette(String name) {
    assert(_palettes.containsKey(name), 'Unknown palette: $name');
    _activePalette = name;
  }

  static void registerPalette(String name, FThemePalette palette) {
    _palettes[name] = palette;
  }

  static FThemeData resolve(
    fbs.Brightness? brightness,
    bool touch, {
    double borderRadius = 0.0,
    double borderWidth = 0.0,
  }) {
    final palette = _palettes[_activePalette] ?? FThemes.neutral;
    final isDark = brightness == fbs.Brightness.Dark;
    final platform = isDark ? palette.dark : palette.light;
    final base = touch ? platform.touch : platform.desktop;

    if (borderRadius == 0.0 && borderWidth == 0.0) return base;

    return base.copyWith(
      style: FStyleDelta.delta(
        borderRadius: borderRadius != 0.0
            ? base.style.borderRadius.scale(borderRadius)
            : null,
        borderWidth: borderWidth != 0.0 ? borderWidth : null,
      ),
    );
  }
}
