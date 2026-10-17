/// Value object describing a trip's cover banner. The crop is non-destructive:
/// the original image is kept and framed by [scale] + [alignX]/[alignY].
library;

enum BannerKind { photo, gradient, solid }

enum BannerStyle { classic, minimal, bold, framed }

enum TitlePlacement { topLeft, center, bottomLeft, bottomCenter }

class BannerConfig {
  const BannerConfig({
    this.kind = BannerKind.gradient,
    this.imagePath,
    this.scale = 1.0,
    this.alignX = 0,
    this.alignY = 0,
    required this.colorA,
    this.colorB,
    this.showTitle = true,
    this.titlePlacement = TitlePlacement.bottomLeft,
    this.textColor = 0xFFFFFFFF,
    this.style = BannerStyle.classic,
  });

  /// Deterministic default gradient so each new trip looks distinct.
  factory BannerConfig.defaultFor(String seed) {
    final pair =
        bannerGradients[seed.codeUnits.fold<int>(0, (a, b) => a + b) %
            bannerGradients.length];
    return BannerConfig(colorA: pair.$1, colorB: pair.$2);
  }

  final BannerKind kind;

  /// Media path relative to the media store; only meaningful for photo banners.
  final String? imagePath;
  final double scale;
  final double alignX;
  final double alignY;
  final int colorA;
  final int? colorB;
  final bool showTitle;
  final TitlePlacement titlePlacement;
  final int textColor;
  final BannerStyle style;

  bool get hasImage => kind == BannerKind.photo && imagePath != null;

  /// Same banner with its photo removed, falling back to its colors.
  BannerConfig withoutImage() => copyWith(
    kind: colorB == null ? BannerKind.solid : BannerKind.gradient,
    clearImage: true,
  );

  /// Uses [relPath] as the photo, with the crop reset.
  BannerConfig withImage(String relPath) => copyWith(
    kind: BannerKind.photo,
    imagePath: relPath,
    scale: 1,
    alignX: 0,
    alignY: 0,
  );

  BannerConfig copyWith({
    BannerKind? kind,
    String? imagePath,
    bool clearImage = false,
    double? scale,
    double? alignX,
    double? alignY,
    int? colorA,
    int? colorB,
    bool clearColorB = false,
    bool? showTitle,
    TitlePlacement? titlePlacement,
    int? textColor,
    BannerStyle? style,
  }) => BannerConfig(
    kind: kind ?? this.kind,
    imagePath: clearImage ? null : (imagePath ?? this.imagePath),
    scale: scale ?? this.scale,
    alignX: alignX ?? this.alignX,
    alignY: alignY ?? this.alignY,
    colorA: colorA ?? this.colorA,
    colorB: clearColorB ? null : (colorB ?? this.colorB),
    showTitle: showTitle ?? this.showTitle,
    titlePlacement: titlePlacement ?? this.titlePlacement,
    textColor: textColor ?? this.textColor,
    style: style ?? this.style,
  );

  @override
  bool operator ==(Object other) =>
      other is BannerConfig &&
      other.kind == kind &&
      other.imagePath == imagePath &&
      other.scale == scale &&
      other.alignX == alignX &&
      other.alignY == alignY &&
      other.colorA == colorA &&
      other.colorB == colorB &&
      other.showTitle == showTitle &&
      other.titlePlacement == titlePlacement &&
      other.textColor == textColor &&
      other.style == style;

  @override
  int get hashCode => Object.hash(
    kind,
    imagePath,
    scale,
    alignX,
    alignY,
    colorA,
    colorB,
    showTitle,
    titlePlacement,
    textColor,
    style,
  );
}

const bannerGradients = <(int, int)>[
  (0xFF254F3E, 0xFF35624C),
  (0xFF6B4C3B, 0xFF89644A),
  (0xFF4D5E48, 0xFF6A7856),
  (0xFF355354, 0xFF486B67),
  (0xFF76543A, 0xFF937149),
  (0xFF594942, 0xFF7A5D50),
  (0xFF3D5144, 0xFF5A6D57),
  (0xFF4D5350, 0xFF68716A),
];

const bannerSolidColors = <int>[
  0xFF0F766E,
  0xFF1D4ED8,
  0xFF7C3AED,
  0xFFBE123C,
  0xFFEA580C,
  0xFF15803D,
  0xFF334155,
  0xFF111827,
];

const bannerTextColors = <int>[0xFFFFFFFF, 0xFF111827, 0xFFFDE68A, 0xFFBAE6FD];
