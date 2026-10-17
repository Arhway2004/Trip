import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/contexts/places/application/location_link_service.dart';
import 'package:wanderplan/contexts/places/domain/location_link.dart';
import 'package:wanderplan/l10n/gen/app_localizations.dart';
import 'package:wanderplan/shared/domain/geo_point.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';
import 'package:wanderplan/shared/presentation/theme/app_theme.dart';

String locationLinkError(AppLocalizations l, Object e) => switch (e) {
  LocationLinkException(failure: LocationLinkFailure.shortLinkFailed) => l.linkShortFailed,
  LocationLinkException(failure: LocationLinkFailure.plusCodeNeedsArea) => l.linkPlusNeedsArea,
  _ => l.linkUnrecognized,
};

/// A short note about how a pasted location was read, for a snackbar.
String? resolvedLocationNote(AppLocalizations l, ResolvedLocation r) => !r.exactPlace
    ? l.linkCentreOnly
    : r.convertedFromGcj02
    ? l.linkConverted
    : null;

/// Lets the user paste a Google Maps link (full, short or embed code), Amap /
/// Apple Maps link, "lat, lng" or a Plus Code, and returns WGS84 coordinates.
Future<ResolvedLocation?> showPasteLocationDialog(BuildContext context, {GeoPoint? near, String? initialText}) =>
    showDialog<ResolvedLocation>(
      context: context,
      builder: (_) => _PasteLocationDialog(near: near, initialText: initialText),
    );

class _PasteLocationDialog extends ConsumerStatefulWidget {
  const _PasteLocationDialog({this.near, this.initialText});
  final GeoPoint? near;
  final String? initialText;

  @override
  ConsumerState<_PasteLocationDialog> createState() => _PasteLocationDialogState();
}

class _PasteLocationDialogState extends ConsumerState<_PasteLocationDialog> {
  late final _text = TextEditingController(text: widget.initialText);
  bool _fromChineseMap = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialText == null) _prefillFromClipboard();
  }

  Future<void> _prefillFromClipboard() async {
    try {
      final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      if (clip != null && parseLocationText(clip) != null && mounted && _text.text.isEmpty) {
        setState(() => _text.text = clip.trim());
      }
    } catch (_) {
      // Clipboard unavailable: the user pastes by hand.
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Plain coordinates and Plus Codes don't say which map they came from.
  bool get _askOrigin => switch (parseLocationText(_text.text)) {
    ParsedCoordinates(:final origin, :final point) => origin == CoordinateOrigin.plain && Gcj02.appliesTo(point),
    PlusCodeText() => true,
    _ => false,
  };

  Future<void> _resolve() async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref
          .read(locationLinkServiceProvider)
          .resolve(_text.text, near: widget.near, plainFromChineseMap: _fromChineseMap);
      if (mounted) Navigator.pop(context, r);
    } catch (e) {
      if (mounted) setState(() => _error = locationLinkError(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    return AlertDialog(
      title: Text(l.pasteLocation),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _text,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: l.pasteLocationHint,
                errorText: _error,
                errorMaxLines: 3,
                suffixIcon: IconButton(
                  tooltip: l.pasteFromClipboard,
                  icon: const Icon(Icons.content_paste),
                  onPressed: () async {
                    final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
                    if (clip != null) setState(() => _text.text = clip.trim());
                  },
                ),
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            if (_askOrigin) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _fromChineseMap,
                onChanged: (v) => setState(() => _fromChineseMap = v),
                title: Text(l.pasteFromChineseMap, style: const TextStyle(fontSize: 14)),
                subtitle: Text(l.pasteFromChineseMapHelp, style: TextStyle(fontSize: 12, color: c.ink3)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionCancel)),
        FilledButton(
          onPressed: _busy || _text.text.trim().isEmpty ? null : _resolve,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l.pasteResolve),
        ),
      ],
    );
  }
}
