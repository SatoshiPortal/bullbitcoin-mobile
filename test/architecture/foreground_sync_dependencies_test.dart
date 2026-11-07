import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

String? _target(String source, String uri) {
  if (uri.startsWith('package:bb_mobile/')) {
    return 'lib/${uri.substring('package:bb_mobile/'.length)}';
  }
  if (Uri.parse(uri).hasScheme) return null;
  return p.normalize(p.join(p.dirname(source), uri));
}

Iterable<String> _dependencies(String file, {bool exportsOnly = false}) sync* {
  final unit = parseString(content: File(file).readAsStringSync()).unit;
  for (final directive in unit.directives) {
    if (directive is! ExportDirective &&
        (exportsOnly || directive is! ImportDirective)) {
      continue;
    }
    final uris = <String?>[
      if (directive is UriBasedDirective) directive.uri.stringValue,
      if (directive is ImportDirective)
        ...directive.configurations.map((c) => c.uri.stringValue),
      if (directive is ExportDirective)
        ...directive.configurations.map((c) => c.uri.stringValue),
    ];
    for (final uri in uris.whereType<String>()) {
      final target = _target(file, uri);
      if (target != null && File(target).existsSync()) yield target;
    }
  }
}

void main() {
  test('SP and swap cannot reach wallet synchronization through barrels', () {
    final violations = <String>[];
    for (final feature in ['sp', 'swap']) {
      for (final file
          in Directory('lib/features/$feature')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        final pending = _dependencies(file.path).toList();
        final seen = <String>{};
        while (pending.isNotEmpty) {
          final target = pending.removeLast();
          if (!seen.add(target)) continue;
          if (target.startsWith('lib/features/wallet/') &&
              p.basename(target).contains('sync') &&
              !target.contains('/public/')) {
            violations.add('${file.path} -> $target');
          }
          // Public facades own their exports. Compatibility barrels do not
          // hide the owner of an imported symbol.
          if (!target.contains('/public/')) {
            pending.addAll(_dependencies(target, exportsOnly: true));
          }
        }
      }
    }
    expect(violations, isEmpty);
  });
}
