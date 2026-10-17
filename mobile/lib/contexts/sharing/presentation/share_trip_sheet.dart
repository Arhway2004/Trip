import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:wanderplan/app/router.dart';
import 'package:wanderplan/l10n/gen/app_localizations.dart';
import 'package:wanderplan/shared/presentation/theme/app_theme.dart';
import 'package:wanderplan/shared/presentation/widgets.dart';
import 'package:wanderplan/shared/presentation/l10n_helpers.dart';
import 'package:wanderplan/contexts/trip/presentation/trip_providers.dart';
import 'package:wanderplan/app/providers.dart';
import 'package:wanderplan/contexts/sharing/application/trip_package_service.dart';

/// Bottom sheet that packages a trip and hands it to the system share sheet
/// (Messages, LINE, WeChat, email, AirDrop, Nearby Share, …).
Future<void> showShareTripSheet(BuildContext context, TripSummary trip) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => _ShareSheet(trip: trip),
);

class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({required this.trip});
  final TripSummary trip;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  bool _includePhotos = true;
  bool _busy = false;

  Future<void> _share() async {
    final l = context.l10n;
    final box = context.findRenderObject() as RenderBox?;
    setState(() => _busy = true);
    try {
      final file = await ref.read(tripPackageServiceProvider).exportTrip(widget.trip.id, includePhotos: _includePhotos);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/zip')],
          text: l.shareMessage(widget.trip.trip.title),
          subject: widget.trip.trip.title,
          // Required for the iPad popover anchor.
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.shareFailed('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final photoCount = widget.trip.photoCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.shareTrip, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(l.shareExplain),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.shareIncludePhotos),
            subtitle: Text(l.shareIncludePhotosHelp(photoCount)),
            value: _includePhotos && photoCount > 0,
            onChanged: photoCount == 0 ? null : (v) => setState(() => _includePhotos = v),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _share,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share),
            label: Text(l.shareSend),
          ),
        ],
      ),
    );
  }
}

/// Import entry point: lets the user choose between picking a file and
/// pasting trip JSON text. Both paths share validation and error reporting.
Future<void> importTripFromFile(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l.importHow, style: Theme.of(c).textTheme.titleMedium),
          ),
          ListTile(
            leading: const Icon(Icons.file_open_outlined),
            title: Text(l.importChooseFile),
            subtitle: Text(l.importChooseFileHelp),
            onTap: () => Navigator.pop(c, 'file'),
          ),
          ListTile(
            leading: const Icon(Icons.content_paste),
            title: Text(l.importPaste),
            subtitle: Text(l.importPasteHelp),
            onTap: () => Navigator.pop(c, 'paste'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (choice == 'file') {
    await _importFromFile(context, ref);
  } else if (choice == 'paste') {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const _PasteImportScreen()));
  }
}

Future<void> _importFromFile(BuildContext context, WidgetRef ref) async {
  // Custom extensions aren't registered as system file types, so any file is
  // allowed and the content is validated instead.
  final picked = await FilePicker.pickFiles();
  final path = picked.firstOrNull?.path;
  if (path == null || !context.mounted) return;
  await _runImport(context, ref, () => ref.read(tripPackageServiceProvider).importFile(File(path)));
}

/// Runs an import, then opens the new trip; on failure shows the exact reason.
/// Returns true on success.
Future<bool> _runImport(BuildContext context, WidgetRef ref, Future<String> Function() run) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  try {
    final id = await run();
    final trip = await ref.read(tripServiceProvider).getTrip(id);
    messenger.showSnackBar(SnackBar(content: Text(l.importSuccess(trip?.title ?? ''))));
    router.go(Routes.trip(id));
    return true;
  } on TripPackageException catch (e) {
    messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 8), content: Text(importErrorText(l, e))));
    return false;
  }
}

String importErrorText(AppLocalizations l, TripPackageException e) => switch (e.error) {
  TripPackageError.tooNew => l.importTooNew,
  TripPackageError.invalid when e.detail != null => l.importInvalidDetail(e.detail!),
  TripPackageError.invalid => l.importInvalid,
};

class _PasteImportScreen extends ConsumerStatefulWidget {
  const _PasteImportScreen();

  @override
  ConsumerState<_PasteImportScreen> createState() => _PasteImportScreenState();
}

class _PasteImportScreenState extends ConsumerState<_PasteImportScreen> {
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text ?? '';
    if (!mounted) return;
    if (t.trim().isEmpty) {
      setState(() => _error = context.l10n.clipboardEmpty);
      return;
    }
    setState(() {
      _text.text = t;
      _error = null;
    });
  }

  Future<void> _import() async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref.read(tripPackageServiceProvider).importText(_text.text);
      final trip = await ref.read(tripServiceProvider).getTrip(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.importSuccess(trip?.title ?? ''))));
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.go(Routes.trip(id));
    } on TripPackageException catch (e) {
      // Keep the text so the user can fix it in place.
      if (mounted) setState(() => _error = importErrorText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.importPaste),
        actions: [
          TextButton(onPressed: _busy || _text.text.trim().isEmpty ? null : _import, child: Text(l.importAction)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.importPasteHelp, style: TextStyle(color: c.ink2)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _paste,
                  icon: const Icon(Icons.content_paste),
                  label: Text(l.pasteFromClipboard),
                ),
                if (_text.text.isNotEmpty)
                  TextButton(onPressed: () => setState(() => _text.clear()), child: Text(l.actionClear)),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Badge2(label: _error!, tone: Tone.bad, icon: Icons.error_outline),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _text,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                autocorrect: false,
                enableSuggestions: false,
                smartQuotesType: SmartQuotesType.disabled,
                smartDashesType: SmartDashesType.disabled,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(hintText: l.importPasteHint, alignLabelWithHint: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy || _text.text.trim().isEmpty ? null : _import,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_done),
              label: Text(l.importAction),
            ),
          ],
        ),
      ),
    );
  }
}
