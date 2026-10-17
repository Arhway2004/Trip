import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the DDD layering so the codebase stays maintainable:
/// - domain: pure Dart (no Flutter, Drift, Riverpod, other layers)
/// - application: may use domain + shared ports, never infrastructure/presentation
///   (the composition root lives in lib/app)
/// - contexts only reach into another context's domain/application, never its
///   infrastructure or presentation.
void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart') && !f.path.contains('/l10n/gen/'))
      .toList();

  List<String> importsOf(File f) => RegExp(
    r"""^import\s+'([^']+)'""",
    multiLine: true,
  ).allMatches(f.readAsStringSync()).map((m) => m.group(1)!).toList();

  String? layerOf(String path) =>
      RegExp(r'/(domain|application|infrastructure|presentation)/').firstMatch(path)?.group(1);

  test('domain layers are pure Dart', () {
    final violations = <String>[];
    for (final f in files.where((f) => layerOf(f.path) == 'domain')) {
      for (final i in importsOf(f)) {
        final bad =
            i.startsWith('package:flutter') ||
            i.startsWith('package:drift') ||
            i.startsWith('package:flutter_riverpod') ||
            RegExp(r'/(application|infrastructure|presentation)/').hasMatch(i) ||
            i.startsWith('package:wanderplan/app/');
        if (bad) violations.add('${f.path} -> $i');
      }
    }
    expect(violations, isEmpty);
  });

  test('application layers do not depend on infrastructure, presentation or Flutter', () {
    final violations = <String>[];
    for (final f in files.where((f) => layerOf(f.path) == 'application')) {
      for (final i in importsOf(f)) {
        final ownInfra =
            i.contains('/infrastructure/') &&
            // A context may use its own codec adapters (e.g. sharing's ZIP codec).
            i.split('/contexts/').length > 1 &&
            f.path.contains(i.split('/infrastructure/').first.replaceFirst('package:wanderplan/', 'lib/'));
        final bad =
            i.startsWith('package:flutter') ||
            i.startsWith('package:drift') ||
            i.contains('/presentation/') ||
            i.startsWith('package:wanderplan/app/') ||
            (i.contains('/infrastructure/') && !ownInfra);
        if (bad) violations.add('${f.path} -> $i');
      }
    }
    expect(violations, isEmpty);
  });

  test('contexts never use another context\'s infrastructure or presentation internals directly', () {
    final violations = <String>[];
    for (final f in files.where((f) => f.path.contains('lib/contexts/'))) {
      final own = RegExp(r'lib/contexts/(\w+)/').firstMatch(f.path)!.group(1);
      for (final i in importsOf(f)) {
        final m = RegExp(r'package:wanderplan/contexts/(\w+)/(\w+)/').firstMatch(i);
        if (m == null || m.group(1) == own) continue;
        if (m.group(2) == 'infrastructure') violations.add('${f.path} -> $i');
      }
    }
    expect(violations, isEmpty);
  });

  test('presentation never touches the database directly', () {
    final violations = <String>[
      for (final f in files.where((f) => layerOf(f.path) == 'presentation'))
        for (final i in importsOf(f))
          if (i.contains('/infrastructure/database/') || i.startsWith('package:drift')) '${f.path} -> $i',
    ];
    expect(violations, isEmpty);
  });
}
