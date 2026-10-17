import 'package:flutter/material.dart';

/// Shared travel-atlas tokens: clean neutrals, white surfaces and forest actions.
/// Keep these aligned with frontend/src/styles.css.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.canvas,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.brand,
    required this.brandStrong,
    required this.brandSoft,
    required this.accent,
    required this.good,
    required this.goodBg,
    required this.warn,
    required this.warnBg,
    required this.bad,
    required this.badBg,
    required this.info,
    required this.infoBg,
    required this.chartPlanned,
    required this.chartActual,
  });

  final Color canvas, surface, surface2, line, ink, ink2, ink3;
  final Color brand, brandStrong, brandSoft, accent;
  final Color good, goodBg, warn, warnBg, bad, badBg, info, infoBg;

  /// Validated two-series chart pair (dataviz validator: CVD, contrast, lightness).
  final Color chartPlanned, chartActual;

  static const light = AppColors(
    canvas: Color(0xFFF7F9F8),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF1F4F2),
    line: Color(0xFFDCE3DE),
    ink: Color(0xFF1F2923),
    ink2: Color(0xFF4D5C53),
    ink3: Color(0xFF5C6B62),
    brand: Color(0xFF245C46),
    brandStrong: Color(0xFF194332),
    brandSoft: Color(0xFFEAF2ED),
    accent: Color(0xFFB64B32),
    good: Color(0xFF0A7D2C),
    goodBg: Color(0xFFE6F5EA),
    warn: Color(0xFF8A5A00),
    warnBg: Color(0xFFFFF4D6),
    bad: Color(0xFFB42318),
    badBg: Color(0xFFFDE8E6),
    info: Color(0xFF2A5FB0),
    infoBg: Color(0xFFE8F0FB),
    chartPlanned: Color(0xFF00897A),
    chartActual: Color(0xFFB64B32),
  );

  static const dark = AppColors(
    canvas: Color(0xFF151C18),
    surface: Color(0xFF1E2721),
    surface2: Color(0xFF26322A),
    line: Color(0xFF425047),
    ink: Color(0xFFF0F5F1),
    ink2: Color(0xFFC4CFC7),
    ink3: Color(0xFFA5B4A9),
    brand: Color(0xFFA8C8A0),
    brandStrong: Color(0xFFC1DBB6),
    brandSoft: Color(0xFF2C4935),
    accent: Color(0xFFEF9876),
    good: Color(0xFF4CC86F),
    goodBg: Color(0xFF15301E),
    warn: Color(0xFFF0C36D),
    warnBg: Color(0xFF352A10),
    bad: Color(0xFFFF8A80),
    badBg: Color(0xFF3A1A17),
    info: Color(0xFF8AB4F8),
    infoBg: Color(0xFF17263B),
    chartPlanned: Color(0xFF2AA38E),
    chartActual: Color(0xFFDB6B48),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

const appRadius = 8.0;

/// Folios use fine borders rather than floating elevation.
List<BoxShadow> softShadow(Brightness b) => const [];

const atlasBodyFallback = [
  'Noto Sans SC',
  'Noto Sans CJK SC',
  'PingFang SC',
  'Arial Unicode MS',
  'Songti SC',
  'Noto Sans Thai',
  'Thonburi',
];

TextStyle atlasEditorial(
  BuildContext context, {
  double size = 44,
  Color? color,
}) => TextStyle(
  fontFamily: 'Newsreader',
  fontFamilyFallback: const [
    'Noto Serif SC',
    'Songti SC',
    'Noto Sans Thai',
    'Thonburi',
    'Arial Unicode MS',
  ],
  fontVariations: [
    FontVariation('opsz', size),
    const FontVariation('wght', 400),
  ],
  fontSize: size,
  height: 1.08,
  fontWeight: FontWeight.w400,
  letterSpacing: -1.1,
  color: color ?? context.colors.ink,
);
TextStyle atlasEyebrow(BuildContext context) => TextStyle(
  fontFamily: 'DM Sans',
  fontFamilyFallback: atlasBodyFallback,
  fontSize: 10,
  height: 1.5,
  fontWeight: FontWeight.w600,
  letterSpacing: 1.5,
  color: context.colors.ink2,
);

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final scheme =
      ColorScheme.fromSeed(seedColor: c.brand, brightness: brightness).copyWith(
        primary: c.brand,
        onPrimary: brightness == Brightness.dark ? c.canvas : Colors.white,
        primaryContainer: c.brandSoft,
        onPrimaryContainer: c.brandStrong,
        secondary: c.accent,
        surface: c.surface,
        onSurface: c.ink,
        onSurfaceVariant: c.ink2,
        outline: c.ink3,
        outlineVariant: c.line,
        surfaceContainerLowest: c.surface,
        surfaceContainerLow: c.surface2,
        surfaceContainer: c.surface2,
        surfaceContainerHigh: c.surface2,
        surfaceContainerHighest: c.line,
        error: c.bad,
        errorContainer: c.badBg,
        onErrorContainer: c.bad,
      );
  final shape12 = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(6),
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: 'DM Sans',
    fontFamilyFallback: const [
      'Noto Sans SC',
      'Noto Sans CJK SC',
      'PingFang SC',
      'Arial Unicode MS',
      'Noto Sans Thai',
      'Thonburi',
    ],
  );

  return base.copyWith(
    scaffoldBackgroundColor: c.canvas,
    extensions: [c],
    textTheme: base.textTheme
        .copyWith(
          headlineLarge: base.textTheme.headlineLarge?.copyWith(
            fontFamily: 'Newsreader',
            fontFamilyFallback: const [
              'Noto Serif SC',
              'Songti SC',
              'Noto Sans Thai',
              'Thonburi',
              'Arial Unicode MS',
            ],
            fontWeight: FontWeight.w400,
            letterSpacing: -0.8,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontFamily: 'Newsreader',
            fontFamilyFallback: const [
              'Noto Serif SC',
              'Songti SC',
              'Noto Sans Thai',
              'Thonburi',
              'Arial Unicode MS',
            ],
            fontWeight: FontWeight.w400,
            letterSpacing: -0.6,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontFamily: 'Newsreader',
            fontFamilyFallback: const [
              'Noto Serif SC',
              'Songti SC',
              'Noto Sans Thai',
              'Thonburi',
              'Arial Unicode MS',
            ],
            fontWeight: FontWeight.w400,
            letterSpacing: -0.4,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontFamily: 'Newsreader',
            fontFamilyFallback: const [
              'Noto Serif SC',
              'Songti SC',
              'Noto Sans Thai',
              'Thonburi',
              'Arial Unicode MS',
            ],
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(bodyColor: c.ink, displayColor: c.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: c.canvas,
      surfaceTintColor: Colors.transparent,
      foregroundColor: c.ink,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: c.ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(appRadius),
        side: BorderSide(color: c.line),
      ),
    ),
    dividerTheme: DividerThemeData(color: c.line, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: c.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: c.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: c.brand, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: shape12,
        minimumSize: const Size(0, 48),
        textStyle: const TextStyle(
          fontFamily: 'DM Sans',
          fontFamilyFallback: atlasBodyFallback,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: shape12,
        minimumSize: const Size(0, 44),
        side: BorderSide(color: c.line),
        foregroundColor: c.ink,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: shape12),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.brand,
      foregroundColor: Colors.white,
      elevation: 2,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: c.surface,
      selectedColor: c.brandSoft,
      side: BorderSide(color: c.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      labelStyle: TextStyle(
        fontFamily: 'DM Sans',
        fontFamilyFallback: atlasBodyFallback,
        color: c.ink2,
        fontWeight: FontWeight.w500,
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: 'DM Sans',
        fontFamilyFallback: atlasBodyFallback,
        color: c.brandStrong,
        fontWeight: FontWeight.w700,
      ),
      checkmarkColor: c.brandStrong,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: c.surface2,
        selectedBackgroundColor: c.surface,
        selectedForegroundColor: c.ink,
        foregroundColor: c.ink2,
        side: BorderSide(color: c.line),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.line),
      ),
    ),
    listTileTheme: ListTileThemeData(iconColor: c.ink2),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.brand,
      linearTrackColor: c.brandSoft,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      contentTextStyle: TextStyle(color: c.surface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
  );
}
