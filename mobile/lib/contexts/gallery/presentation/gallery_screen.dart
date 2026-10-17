import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:wanderplan/contexts/gallery/domain/photo.dart';
import 'package:wanderplan/contexts/gallery/presentation/gallery_providers.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/shared/presentation/image_pick.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';
import 'package:wanderplan/contexts/trip/presentation/trip_providers.dart';
import 'package:wanderplan/contexts/gallery/presentation/photo_thumbnail.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  bool _favoritesOnly = false;

  Future<void> _add(ImageSource source) async {
    final paths = source == ImageSource.camera
        ? [?(await pickSingleImage(context, ImageSource.camera))]
        : await pickMultipleImages(context);
    if (paths.isEmpty) return;
    await ref.read(galleryServiceProvider).addPhotos(widget.tripId, paths);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final trip = ref.watch(tripProvider(widget.tripId)).value;
    final photos = ref.watch(tripPhotosProvider(widget.tripId)).value ?? const <Photo>[];
    final visible = _favoritesOnly ? photos.where((p) => p.isFavorite).toList() : photos;

    return Scaffold(
      appBar: AppBar(
        title: Text(trip == null ? l.photosTitle : '${l.photosTitle} · ${trip.trip.title}'),
        actions: [
          IconButton(
            tooltip: l.favoritesOnly,
            isSelected: _favoritesOnly,
            icon: const Icon(Icons.favorite_border),
            selectedIcon: const Icon(Icons.favorite),
            onPressed: () => setState(() => _favoritesOnly = !_favoritesOnly),
          ),
        ],
      ),
      floatingActionButton: MenuAnchor(
        menuChildren: [
          MenuItemButton(
            leadingIcon: const Icon(Icons.photo_library_outlined),
            onPressed: () => _add(ImageSource.gallery),
            child: Text(l.galleryFromDevice),
          ),
          MenuItemButton(
            leadingIcon: const Icon(Icons.photo_camera_outlined),
            onPressed: () => _add(ImageSource.camera),
            child: Text(l.coverCamera),
          ),
        ],
        builder: (context, controller, _) => FloatingActionButton.extended(
          onPressed: () => controller.isOpen ? controller.close() : controller.open(),
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text(l.addPhoto),
        ),
      ),
      body: visible.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l.galleryEmpty, textAlign: TextAlign.center),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 96),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: visible.length,
              itemBuilder: (context, i) {
                final p = visible[i];
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _PhotoViewer(tripId: widget.tripId, photoId: p.id),
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: p.id,
                        child: PhotoThumbnail(relPath: p.relPath, size: 160),
                      ),
                      if (p.isFavorite)
                        const Positioned(
                          right: 4,
                          bottom: 4,
                          child: Icon(Icons.favorite, color: Colors.white, size: 18, shadows: [Shadow(blurRadius: 4)]),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _PhotoViewer extends ConsumerStatefulWidget {
  const _PhotoViewer({required this.tripId, required this.photoId});
  final String tripId;
  final String photoId;

  @override
  ConsumerState<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends ConsumerState<_PhotoViewer> {
  TextEditingController? _caption;

  @override
  void dispose() {
    _caption?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final photos = ref.watch(tripPhotosProvider(widget.tripId)).value;
    final photo = photos?.where((p) => p.id == widget.photoId).firstOrNull;
    if (photo == null) return const Scaffold(backgroundColor: Colors.black);
    _caption ??= TextEditingController(text: photo.caption);
    final repo = ref.read(galleryServiceProvider);
    final file = ref.watch(mediaStorageProvider).resolve(photo.relPath);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: l.photoFavorite,
            icon: Icon(photo.isFavorite ? Icons.favorite : Icons.favorite_border),
            onPressed: () => repo.updatePhoto(photo.id, isFavorite: !photo.isFavorite),
          ),
          IconButton(
            tooltip: l.setAsCover,
            icon: const Icon(Icons.wallpaper),
            onPressed: () async {
              await ref.read(tripServiceProvider).setPhotoAsCover(widget.tripId, photo);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.coverUpdated)));
              }
            },
          ),
          IconButton(
            tooltip: l.actionDelete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(l.deletePhotoTitle),
                  content: Text(l.deletePhotoBody),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.actionCancel)),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.actionDelete)),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                Navigator.pop(context);
                await repo.deletePhoto(photo);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: Hero(
                  tag: photo.id,
                  child: Image.file(file, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _caption,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: l.photoCaption,
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.short_text, color: Colors.white54),
                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (v) => repo.updatePhoto(photo.id, caption: v),
                onTapOutside: (_) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  if (_caption!.text != (photo.caption ?? '')) repo.updatePhoto(photo.id, caption: _caption!.text);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
