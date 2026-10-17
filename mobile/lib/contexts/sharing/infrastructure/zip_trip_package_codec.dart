import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:wanderplan/contexts/sharing/domain/trip_package.dart';

/// Encodes/decodes trip packages as ZIP archives (or bare JSON on input).
class ZipTripPackageCodec {
  const ZipTripPackageCodec();

  List<int> encode(TripPackageContents c) {
    final archive = Archive();
    for (final e in c.media.entries) {
      archive.addFile(ArchiveFile.bytes(e.key, e.value));
    }
    archive.addFile(ArchiveFile.string(tripPackageJsonEntry, const JsonEncoder.withIndent('  ').convert(c.json)));
    return ZipEncoder().encodeBytes(archive);
  }

  TripPackageContents decode(List<int> bytes) {
    try {
      if (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
        final archive = ZipDecoder().decodeBytes(bytes);
        final entry = archive.findFile(tripPackageJsonEntry);
        if (entry == null) throw const TripPackageException(TripPackageError.invalid, 'trip.json missing');
        final media = {
          for (final f in archive.files)
            if (f.isFile && f.name != tripPackageJsonEntry) f.name: f.content,
        };
        return TripPackageContents(_object(utf8.decode(entry.content)), media);
      }
      return TripPackageContents(_object(utf8.decode(bytes)), const {});
    } on TripPackageException {
      rethrow;
    } catch (e) {
      throw TripPackageException(TripPackageError.invalid, '$e');
    }
  }

  Map<String, dynamic> _object(String text) {
    final v = jsonDecode(text);
    if (v is! Map<String, dynamic>) throw const TripPackageException(TripPackageError.invalid, 'not an object');
    return v;
  }
}
