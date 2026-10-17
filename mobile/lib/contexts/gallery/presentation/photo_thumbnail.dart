import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wanderplan/app/providers.dart';

/// Square, memory-friendly thumbnail of a stored trip photo.
class PhotoThumbnail extends ConsumerWidget {
  const PhotoThumbnail({super.key, required this.relPath, required this.size});

  final String relPath;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(mediaStorageProvider).resolve(relPath);
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Image.file(
      file,
      fit: BoxFit.cover,
      cacheWidth: px,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}
