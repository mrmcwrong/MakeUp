part of '../main.dart';


///
/// Colors - Soft Yellow/Brown Theme (iOS Widget Inspired)
///
class AppColors {
  static const Map<String, String> displayThemeLabels = {
    'yellow': 'Yellow (Default)',
    'orange': 'Orange',
    'green': 'Green',
    'purple': 'Purple',
    'cyan': 'Cyan',
    'light_grey': 'Grey',
    'baby_pink': 'Pink',
    'baby_blue': 'Blue',
    'burgundy': 'Burgundy',
  };

  static final Map<String, _AppPalette> _palettes = {
    'yellow': const _AppPalette(
      cream: Color(0xFFFFFDF7),
      warmSurface: Color(0xFFFFFAED),
      lightTone: Color(0xFFFFF6E0),
      golden: Color(0xFFFFD88D),
      amber: Color(0xFFFFC247),
      brown: Color(0xFFA8907C),
      darkBrown: Color(0xFF6B5B4D),
      deepBrown: Color(0xFF4A3F35),
      success: Color(0xFF88C057),
      error: Color(0xFFE07856),
      textPrimary: Color(0xFF3D3426),
      textSecondary: Color(0xFF8B7C6B),
    ),
    'orange': const _AppPalette(
      cream: Color(0xFFFFFAF5),
      warmSurface: Color(0xFFFFF1E6),
      lightTone: Color(0xFFFFE6D1),
      golden: Color(0xFFFFC99A),
      amber: Color(0xFFFF9A3C),
      brown: Color(0xFFB7774A),
      darkBrown: Color(0xFF7B4F2F),
      deepBrown: Color(0xFF5A3921),
      success: Color(0xFF75B66A),
      error: Color(0xFFD66A4E),
      textPrimary: Color(0xFF503526),
      textSecondary: Color(0xFF8D6D55),
    ),
    'green': const _AppPalette(
      cream: Color(0xFFF7FCF7),
      warmSurface: Color(0xFFEEF8EE),
      lightTone: Color(0xFFE5F5E5),
      golden: Color(0xFFB7E4B8),
      amber: Color(0xFF69B578),
      brown: Color(0xFF5F8F6E),
      darkBrown: Color(0xFF2E5E3F),
      deepBrown: Color(0xFF1E4B30),
      success: Color(0xFF4E9F3D),
      error: Color(0xFFBF5A5A),
      textPrimary: Color(0xFF203126),
      textSecondary: Color(0xFF5D7768),
    ),
    'purple': const _AppPalette(
      cream: Color(0xFFF9F7FF),
      warmSurface: Color(0xFFF1ECFF),
      lightTone: Color(0xFFE7DFFF),
      golden: Color(0xFFCDB9FF),
      amber: Color(0xFF8D69F0),
      brown: Color(0xFF7560A6),
      darkBrown: Color(0xFF51457A),
      deepBrown: Color(0xFF3B325D),
      success: Color(0xFF6AAE86),
      error: Color(0xFFC66B8B),
      textPrimary: Color(0xFF392F52),
      textSecondary: Color(0xFF736892),
    ),
    'cyan': const _AppPalette(
      cream: Color(0xFFF5FDFF),
      warmSurface: Color(0xFFE9F9FD),
      lightTone: Color(0xFFD9F2F8),
      golden: Color(0xFFA8E4F0),
      amber: Color(0xFF4EBED4),
      brown: Color(0xFF5D97A6),
      darkBrown: Color(0xFF3F6A78),
      deepBrown: Color(0xFF2D4E59),
      success: Color(0xFF5CAD80),
      error: Color(0xFFC96D70),
      textPrimary: Color(0xFF2A4450),
      textSecondary: Color(0xFF648491),
    ),
    'light_grey': const _AppPalette(
      cream: Color(0xFFFBFBFB),
      warmSurface: Color(0xFFF3F4F5),
      lightTone: Color(0xFFE8EAEC),
      golden: Color(0xFFD2D6DB),
      amber: Color(0xFFA6ADB7),
      brown: Color(0xFF7F8793),
      darkBrown: Color(0xFF5A616C),
      deepBrown: Color(0xFF40464E),
      success: Color(0xFF6EAC7A),
      error: Color(0xFFBE6A72),
      textPrimary: Color(0xFF2E333A),
      textSecondary: Color(0xFF6F7782),
    ),
    'baby_pink': const _AppPalette(
      cream: Color(0xFFFFFAFC),
      warmSurface: Color(0xFFFFF2F6),
      lightTone: Color(0xFFFFE9F0),
      golden: Color(0xFFFFCADB),
      amber: Color(0xFFF58FB2),
      brown: Color(0xFFB87B96),
      darkBrown: Color(0xFF8B5A71),
      deepBrown: Color(0xFF6F4358),
      success: Color(0xFF7ABF8C),
      error: Color(0xFFD46A87),
      textPrimary: Color(0xFF4D3441),
      textSecondary: Color(0xFF8A6B7B),
    ),
    'baby_blue': const _AppPalette(
      cream: Color(0xFFF8FCFF),
      warmSurface: Color(0xFFEFF7FF),
      lightTone: Color(0xFFE5F1FF),
      golden: Color(0xFFBEDDFF),
      amber: Color(0xFF78B9FF),
      brown: Color(0xFF6C8FB5),
      darkBrown: Color(0xFF415E7E),
      deepBrown: Color(0xFF2E4664),
      success: Color(0xFF63B68F),
      error: Color(0xFFCF6F6F),
      textPrimary: Color(0xFF2D3F53),
      textSecondary: Color(0xFF6A7F95),
    ),
    'burgundy': const _AppPalette(
      cream: Color(0xFFFFF7F8),
      warmSurface: Color(0xFFFDEBEF),
      lightTone: Color(0xFFF8DCE4),
      golden: Color(0xFFDFA6B8),
      amber: Color(0xFF7C1D3A),
      brown: Color(0xFF652036),
      darkBrown: Color(0xFF4B1628),
      deepBrown: Color(0xFF33101D),
      success: Color(0xFF5A8F71),
      error: Color(0xFFA53B52),
      textPrimary: Color(0xFF321520),
      textSecondary: Color(0xFF6B4452),
    ),
  };

  static String _activeTheme = 'yellow';
  static _AppPalette _activePalette = _palettes['yellow']!;

  static String get activeTheme => _activeTheme;

  static String _normalizeThemeKey(String theme) {
    if (theme == 'crimson') return 'burgundy';
    return theme;
  }

  static void setTheme(String theme) {
    final normalized = _normalizeThemeKey(theme);
    final next = _palettes[normalized] ?? _palettes['yellow']!;
    _activeTheme = _palettes.containsKey(normalized) ? normalized : 'yellow';
    _activePalette = next;
  }

  static List<Color> previewSwatch(String theme) {
    final normalized = _normalizeThemeKey(theme);
    final palette = _palettes[normalized] ?? _palettes['yellow']!;
    return [
      palette.cream,
      palette.warmSurface,
      palette.golden,
      palette.amber,
      palette.deepBrown,
    ];
  }

  static Color get cream => _activePalette.cream;
  static Color get warmSurface => _activePalette.warmSurface;
  static Color get lightYellow => _activePalette.lightTone;
  static Color get golden => _activePalette.golden;
  static Color get amber => _activePalette.amber;
  static Color get brown => _activePalette.brown;
  static Color get darkBrown => _activePalette.darkBrown;
  static Color get deepBrown => _activePalette.deepBrown;
  static Color get success => _activePalette.success;
  static Color get error => _activePalette.error;
  static Color get textPrimary => _activePalette.textPrimary;
  static Color get textSecondary => _activePalette.textSecondary;
}

class _AppPalette {
  final Color cream;
  final Color warmSurface;
  final Color lightTone;
  final Color golden;
  final Color amber;
  final Color brown;
  final Color darkBrown;
  final Color deepBrown;
  final Color success;
  final Color error;
  final Color textPrimary;
  final Color textSecondary;

  const _AppPalette({
    required this.cream,
    required this.warmSurface,
    required this.lightTone,
    required this.golden,
    required this.amber,
    required this.brown,
    required this.darkBrown,
    required this.deepBrown,
    required this.success,
    required this.error,
    required this.textPrimary,
    required this.textSecondary,
  });
}

class AnimatedPoints extends StatelessWidget {
  final int points;
  final double size;

  const AnimatedPoints({super.key, required this.points, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: points),
      duration: const Duration(milliseconds: 900),
      builder: (context, value, child) {
        return Text(
          '$value',
          style: GoogleFonts.dmSans(
            fontSize: size,
            fontWeight: FontWeight.w600,
            color: AppColors.darkBrown,
          ),
        );
      },
    );
  }
}

///
/// MODELS
