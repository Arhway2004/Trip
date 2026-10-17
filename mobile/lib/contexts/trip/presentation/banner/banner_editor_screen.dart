import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/contexts/gallery/domain/photo.dart';
import 'package:wanderplan/shared/presentation/image_pick.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';
import 'package:wanderplan/contexts/gallery/presentation/photo_thumbnail.dart';
import 'package:wanderplan/contexts/trip/domain/trip.dart';
import 'package:wanderplan/contexts/trip/presentation/banner/trip_banner_view.dart';

const maxBannerZoom = 4.0;

class BannerEditorScreen extends ConsumerStatefulWidget {
  const BannerEditorScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<BannerEditorScreen> createState() => _BannerEditorScreenState();
}

class _BannerEditorScreenState extends ConsumerState<BannerEditorScreen> {
  BannerConfig? _cfg;
  String _title = '';
  double _gestureStartScale = 1;

  @override
  void initState() {
    super.initState();
    ref.read(tripServiceProvider).getTrip(widget.tripId).then((t) {
      if (!mounted || t == null) return;
      setState(() {
        _title = t.title;
        _cfg = t.banner;
      });
    });
  }

  void _update(BannerConfig Function(BannerConfig c) f) => setState(() => _cfg = f(_cfg!));

  Future<void> _useNewImage(ImageSource source) async {
    final path = await pickSingleImage(context, source);
    if (path == null) return;
    final rel = await ref.read(tripServiceProvider).importBannerImage(widget.tripId, path);
    _update((c) => c.copyWith(kind: BannerKind.photo, imagePath: rel, scale: 1, alignX: 0, alignY: 0));
  }

  Future<void> _chooseTripPhoto() async {
    final photos = await ref.read(galleryServiceProvider).photosOf(widget.tripId);
    if (!mounted) return;
    final chosen = await showModalBottomSheet<Photo>(
      context: context,
      showDragHandle: true,
      builder: (c) => photos.isEmpty
          ? Padding(padding: const EdgeInsets.all(32), child: Text(c.l10n.bannerNoTripPhotos))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: photos.length,
              itemBuilder: (c, i) => InkWell(
                onTap: () => Navigator.pop(c, photos[i]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: PhotoThumbnail(relPath: photos[i].relPath, size: 120),
                ),
              ),
            ),
    );
    if (chosen != null) {
      _update((c) => c.copyWith(kind: BannerKind.photo, imagePath: chosen.relPath, scale: 1, alignX: 0, alignY: 0));
    }
  }

  Future<void> _save() async {
    await ref.read(tripServiceProvider).saveBanner(widget.tripId, _cfg!);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cfg = _cfg;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.bannerEditorTitle),
        actions: [TextButton(onPressed: cfg == null ? null : _save, child: Text(l.actionSave))],
      ),
      body: cfg == null
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  Padding(padding: const EdgeInsets.all(16), child: _preview(cfg)),
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      Tab(text: l.bannerTabImage),
                      Tab(text: l.bannerTabBackground),
                      Tab(text: l.bannerTabText),
                      Tab(text: l.bannerTabStyle),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(children: [_imageTab(cfg), _backgroundTab(cfg), _textTab(cfg), _styleTab(cfg)]),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _preview(BannerConfig cfg) {
    return AspectRatio(
      aspectRatio: bannerAspectRatio,
      child: LayoutBuilder(
        builder: (context, box) {
          return GestureDetector(
            onScaleStart: cfg.hasImage ? (_) => _gestureStartScale = cfg.scale : null,
            onScaleUpdate: cfg.hasImage
                ? (d) {
                    // Dragging moves the image with the finger; a drag of half the
                    // frame width sweeps the whole alignment range.
                    final s = (_gestureStartScale * d.scale).clamp(1.0, maxBannerZoom);
                    _update(
                      (c) => c.copyWith(
                        scale: s,
                        alignX: (c.alignX - d.focalPointDelta.dx / (box.maxWidth / 2)).clamp(-1.0, 1.0),
                        alignY: (c.alignY - d.focalPointDelta.dy / (box.maxHeight / 2)).clamp(-1.0, 1.0),
                      ),
                    );
                  }
                : null,
            child: TripBannerView(config: cfg, title: _title, borderRadius: BorderRadius.circular(20)),
          );
        },
      ),
    );
  }

  Widget _imageTab(BannerConfig cfg) {
    final l = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _useNewImage(ImageSource.gallery),
              icon: const Icon(Icons.upload_outlined),
              label: Text(l.bannerFromDevice),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _useNewImage(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(l.coverCamera),
            ),
            FilledButton.tonalIcon(
              onPressed: _chooseTripPhoto,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(l.bannerFromTrip),
            ),
          ],
        ),
        if (cfg.hasImage) ...[
          const SizedBox(height: 16),
          Text(l.bannerAdjustHint, style: Theme.of(context).textTheme.bodySmall),
          Row(
            children: [
              Text(l.bannerZoom),
              Expanded(
                child: Slider(
                  min: 1,
                  max: maxBannerZoom,
                  value: cfg.scale.clamp(1, maxBannerZoom),
                  onChanged: (v) => _update((c) => c.copyWith(scale: v)),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _update((c) => c.copyWith(scale: 1, alignX: 0, alignY: 0)),
                icon: const Icon(Icons.crop_free),
                label: Text(l.bannerResetCrop),
              ),
              OutlinedButton.icon(
                onPressed: () => _update(
                  (c) => c.copyWith(kind: c.colorB == null ? BannerKind.solid : BannerKind.gradient, clearImage: true),
                ),
                icon: const Icon(Icons.palette_outlined),
                label: Text(l.bannerRemoveImage),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _backgroundTab(BannerConfig cfg) {
    final l = context.l10n;
    BannerKind kindFor(BannerKind colorKind) => cfg.hasImage ? BannerKind.photo : colorKind;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (cfg.hasImage) Text(l.bannerColorsBehindImage, style: Theme.of(context).textTheme.bodySmall),
        Text(l.bannerGradient, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (a, b) in bannerGradients)
              _Swatch(
                colors: [Color(a), Color(b)],
                selected: cfg.colorA == a && cfg.colorB == b,
                onTap: () => _update((c) => c.copyWith(kind: kindFor(BannerKind.gradient), colorA: a, colorB: b)),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(l.bannerSolid, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final a in bannerSolidColors)
              _Swatch(
                colors: [Color(a)],
                selected: cfg.colorA == a && cfg.colorB == null,
                onTap: () => _update((c) => c.copyWith(kind: kindFor(BannerKind.solid), colorA: a, clearColorB: true)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _textTab(BannerConfig cfg) {
    final l = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.bannerShowTitle),
          value: cfg.showTitle,
          onChanged: (v) => _update((c) => c.copyWith(showTitle: v)),
        ),
        Text(l.bannerPlacement, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final p in TitlePlacement.values)
              ChoiceChip(
                label: Text(p.label(l)),
                selected: cfg.titlePlacement == p,
                onSelected: cfg.showTitle ? (_) => _update((c) => c.copyWith(titlePlacement: p)) : null,
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(l.bannerTextColor, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: [
            for (final c in bannerTextColors)
              _Swatch(
                colors: [Color(c)],
                selected: cfg.textColor == c,
                onTap: cfg.showTitle ? () => _update((x) => x.copyWith(textColor: c)) : null,
              ),
          ],
        ),
      ],
    );
  }

  Widget _styleTab(BannerConfig cfg) {
    final l = context.l10n;
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: bannerAspectRatio,
      children: [
        for (final s in BannerStyle.values)
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _update((c) => c.copyWith(style: s)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  width: cfg.style == s ? 3 : 1,
                  color: cfg.style == s ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
                ),
              ),
              padding: const EdgeInsets.all(3),
              child: TripBannerView(
                config: cfg.copyWith(style: s, showTitle: true),
                title: s.label(l),
                titleScale: 0.6,
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.colors, required this.selected, required this.onTap});
  final List<Color> colors;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.first,
          gradient: colors.length > 1 ? LinearGradient(colors: colors) : null,
          border: Border.all(
            width: selected ? 3 : 1,
            color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
          ),
        ),
        child: selected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
      ),
    );
  }
}
