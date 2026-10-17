import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/shared/presentation/atlas.dart';
import 'package:wanderplan/contexts/trip/domain/trip.dart';

/// Aspect ratio shared by the editor preview and trip cards, so what the user
/// frames in the editor is what they see on the home screen.
const bannerAspectRatio = 16 / 9;

/// Renders a trip banner from its [BannerConfig]. The crop is applied at draw
/// time (cover fit + zoom around the alignment point), so the original image
/// is never modified.
class TripBannerView extends ConsumerWidget {
  const TripBannerView({
    super.key,
    required this.config,
    required this.title,
    this.subtitle,
    this.titleScale = 1,
    this.borderRadius,
    this.contentPadding = const EdgeInsets.all(16),
  });

  final BannerConfig config;
  final String title;
  final String? subtitle;
  final double titleScale;
  final BorderRadius? borderRadius;

  /// Inset for the title overlay, e.g. to keep clear of buttons on top.
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(mediaStorageProvider);
    final File? file = config.hasImage
        ? media.resolve(config.imagePath!)
        : null;

    Widget content = LayoutBuilder(
      builder: (context, box) {
        return Stack(
          fit: StackFit.expand,
          children: [
            _Background(config: config),
            if (file != null)
              BannerImage(file: file, config: config, width: box.maxWidth),
            if (config.showTitle) ..._overlay(context, box),
          ],
        );
      },
    );

    if (borderRadius != null) {
      content = ClipRRect(borderRadius: borderRadius!, child: content);
    }
    return content;
  }

  List<Widget> _overlay(BuildContext context, BoxConstraints box) {
    final style = config.style;
    final color = Color(config.textColor);
    final darkText = color.computeLuminance() < 0.4;
    final scrimColor = darkText ? Colors.white : Colors.black;
    final align = switch (config.titlePlacement) {
      TitlePlacement.topLeft => Alignment.topLeft,
      TitlePlacement.center => Alignment.center,
      TitlePlacement.bottomLeft => Alignment.bottomLeft,
      TitlePlacement.bottomCenter => Alignment.bottomCenter,
    };
    final textAlign = (align.x == 0) ? TextAlign.center : TextAlign.start;
    final base = Theme.of(context).textTheme;
    final titleStyle =
        (style == BannerStyle.bold ? base.headlineLarge : base.headlineSmall)!
            .copyWith(
              color: color,
              fontFamily: 'Newsreader',
              fontVariations: [
                FontVariation('opsz', style == BannerStyle.bold ? 38 : 30),
                FontVariation('wght', style == BannerStyle.bold ? 600 : 400),
              ],
              fontSize: style == BannerStyle.bold ? 38 : 30,
              fontWeight: style == BannerStyle.bold
                  ? FontWeight.w600
                  : FontWeight.w400,
              letterSpacing: style == BannerStyle.bold ? -0.5 : null,
              shadows: style == BannerStyle.minimal || !config.hasImage
                  ? null
                  : [
                      Shadow(
                        color: scrimColor.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
            );

    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: align.x == 0
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            title,
            textAlign: textAlign,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textScaler: TextScaler.linear(titleScale),
            style: titleStyle,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            textAlign: textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: base.titleSmall?.copyWith(
              color: color.withValues(alpha: 0.9),
            ),
          ),
      ],
    );

    return [
      if (config.hasImage && style != BannerStyle.minimal)
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: align.y <= 0 && align != Alignment.center
                  ? Alignment.bottomCenter
                  : Alignment.topCenter,
              end: align.y <= 0 && align != Alignment.center
                  ? Alignment.topCenter
                  : Alignment.bottomCenter,
              colors: [
                scrimColor.withValues(alpha: 0),
                scrimColor.withValues(
                  alpha: style == BannerStyle.bold ? 0.65 : 0.45,
                ),
              ],
              stops: const [0.35, 1],
            ),
          ),
        ),
      Padding(
        padding: contentPadding,
        child: Align(
          alignment: align,
          child: style == BannerStyle.framed
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: color, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    color: scrimColor.withValues(alpha: 0.25),
                  ),
                  child: text,
                )
              : text,
        ),
      ),
    ];
  }
}

class _Background extends StatelessWidget {
  const _Background({required this.config});
  final BannerConfig config;

  @override
  Widget build(BuildContext context) {
    final a = Color(config.colorA);
    final b = config.colorB == null ? null : Color(config.colorB!);
    final useGradient = b != null && config.kind != BannerKind.solid;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: a,
        gradient: useGradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [a, b],
              )
            : null,
      ),
      // Photo banners cover this; color banners get a subtle mountain skyline.
      child: config.hasImage ? null : const AtlasRouteArt(),
    );
  }
}

/// Cover-fitted image zoomed by [BannerConfig.scale] around the alignment
/// point. Decodes at display size to keep memory low.
class BannerImage extends StatelessWidget {
  const BannerImage({
    super.key,
    required this.file,
    required this.config,
    required this.width,
  });

  final File file;
  final BannerConfig config;
  final double width;

  @override
  Widget build(BuildContext context) {
    final align = Alignment(config.alignX, config.alignY);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = width.isFinite
        ? (width * dpr * config.scale).clamp(200, 3000).round()
        : null;
    return ClipRect(
      child: Transform.scale(
        scale: config.scale,
        alignment: align,
        child: Image.file(
          file,
          fit: BoxFit.cover,
          alignment: align,
          cacheWidth: cacheWidth,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
