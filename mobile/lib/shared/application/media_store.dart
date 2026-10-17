import 'dart:io';

/// Port for storing binary media (photos, banner images) belonging to trips.
/// Paths handed out are relative so they survive app reinstalls / restores.
abstract interface class MediaStore {
  File resolve(String relPath);

  /// Copies [sourcePath] into the trip's media folder; returns its relative path.
  Future<String> importFile(String tripId, String sourcePath);

  /// Writes [bytes] as a new media file for the trip; returns its relative path.
  Future<String> writeBytes(String tripId, List<int> bytes, {required String extension});

  Future<String> copyToTrip(String relPath, String tripId);
  Future<void> deleteFile(String relPath);
  Future<void> deleteTripMedia(String tripId);
  Future<void> deleteAll();
}
