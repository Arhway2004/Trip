/// A photo stored for a trip. Entity of the Gallery context.
class Photo {
  const Photo({
    required this.id,
    required this.tripId,
    required this.relPath,
    this.caption,
    this.isFavorite = false,
    required this.createdAt,
  });

  final String id;
  final String tripId;

  /// Path relative to the media store.
  final String relPath;
  final String? caption;
  final bool isFavorite;
  final DateTime createdAt;

  Photo copyWith({
    String? id,
    String? tripId,
    String? relPath,
    String? caption,
    bool clearCaption = false,
    bool? isFavorite,
    DateTime? createdAt,
  }) => Photo(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    relPath: relPath ?? this.relPath,
    caption: clearCaption ? null : (caption ?? this.caption),
    isFavorite: isFavorite ?? this.isFavorite,
    createdAt: createdAt ?? this.createdAt,
  );
}
