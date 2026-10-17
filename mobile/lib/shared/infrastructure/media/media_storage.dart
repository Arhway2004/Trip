import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wanderplan/shared/application/media_store.dart';

/// File-system [MediaStore] inside the app sandbox.
class MediaStorage implements MediaStore {
  MediaStorage(this.root);

  final Directory root;

  static Future<MediaStorage> appDefault() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'media'));
    await dir.create(recursive: true);
    return MediaStorage(dir);
  }

  @override
  File resolve(String relPath) => File(p.join(root.path, relPath));

  String _newRel(String tripId, String ext) =>
      p.join('trips', tripId, '${const Uuid().v4()}${ext.isEmpty ? '.jpg' : ext.toLowerCase()}');

  @override
  Future<String> importFile(String tripId, String sourcePath) async {
    final rel = _newRel(tripId, p.extension(sourcePath));
    final dest = resolve(rel);
    await dest.parent.create(recursive: true);
    await File(sourcePath).copy(dest.path);
    return rel;
  }

  @override
  Future<String> writeBytes(String tripId, List<int> bytes, {required String extension}) async {
    final rel = _newRel(tripId, extension);
    final dest = resolve(rel);
    await dest.parent.create(recursive: true);
    await dest.writeAsBytes(bytes);
    return rel;
  }

  @override
  Future<String> copyToTrip(String relPath, String tripId) => importFile(tripId, resolve(relPath).path);

  @override
  Future<void> deleteFile(String relPath) async {
    final f = resolve(relPath);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<void> deleteTripMedia(String tripId) async {
    final dir = Directory(p.join(root.path, 'trips', tripId));
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  @override
  Future<void> deleteAll() async {
    if (await root.exists()) await root.delete(recursive: true);
    await root.create(recursive: true);
  }
}
