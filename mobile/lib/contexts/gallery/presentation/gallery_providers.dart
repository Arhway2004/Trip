import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/contexts/gallery/domain/photo.dart';

final tripPhotosProvider = StreamProvider.family<List<Photo>, String>(
  (ref, id) => ref.watch(galleryServiceProvider).watchPhotos(id),
);
