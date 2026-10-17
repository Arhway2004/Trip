import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:wanderplan/shared/presentation/l10n_helpers.dart';

/// Picked images are downscaled and recompressed so stored media stays small
/// enough for smooth scrolling while still looking sharp as a banner.
const _maxDimension = 2048.0;
const _quality = 85;

Future<String?> pickSingleImage(BuildContext context, ImageSource source) async {
  try {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
      imageQuality: _quality,
      requestFullMetadata: false,
    );
    return file?.path;
  } on PlatformException {
    if (context.mounted) _showAccessError(context);
    return null;
  }
}

Future<List<String>> pickMultipleImages(BuildContext context) async {
  try {
    final files = await ImagePicker().pickMultiImage(
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
      imageQuality: _quality,
      requestFullMetadata: false,
    );
    return files.map((f) => f.path).toList();
  } on PlatformException {
    if (context.mounted) _showAccessError(context);
    return const [];
  }
}

void _showAccessError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.photoAccessError)));
}
