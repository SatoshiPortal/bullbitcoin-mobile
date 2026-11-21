import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _retiredDirectories = ['lib/core/widgets', 'lib/core/screens'];

Iterable<File> _dartSources(Directory directory) sync* {
  for (final entry in directory.listSync(followLinks: false)) {
    if (entry is File && p.extension(entry.path) == '.dart') {
      yield entry;
    }
    if (entry is Directory) {
      final name = p.basename(entry.path);
      if (name.startsWith('.') || name == 'build' || name == 'node_modules') {
        continue;
      }
      yield* _dartSources(entry);
    }
  }
}

Iterable<String> _retiredReferences(File source) sync* {
  final unit = parseString(
    content: source.readAsStringSync(),
    path: source.path,
    throwIfDiagnostics: false,
  ).unit;
  for (final directive in unit.directives) {
    final uris = switch (directive) {
      ImportDirective(:final uri, :final configurations) ||
      ExportDirective(
        :final uri,
        :final configurations,
      ) => [uri, for (final configuration in configurations) configuration.uri],
      PartDirective(:final uri) => [uri],
      _ => const <StringLiteral>[],
    };
    for (final uri in uris) {
      final reference = uri.stringValue;
      if (reference == null) continue;
      const appPackage = 'package:bb_mobile/';
      final target = p.normalize(
        reference.startsWith(appPackage)
            ? p.join('lib', reference.substring(appPackage.length))
            : p.join(p.dirname(source.path), reference),
      );
      if (_retiredDirectories.any(
        (directory) => target == directory || p.isWithin(directory, target),
      )) {
        yield '${source.path}: $reference';
      }
    }
  }
}

void main() {
  test('the retired core UI directories stay absent', () {
    final present = _retiredDirectories.where(
      (directory) =>
          FileSystemEntity.typeSync(directory, followLinks: false) !=
          FileSystemEntityType.notFound,
    );
    expect(present, isEmpty);
  });

  test('Dart sources never reference retired core UI', () {
    final references = _dartSources(
      Directory('.'),
    ).expand(_retiredReferences).toList()..sort();
    expect(references, isEmpty);
  });
}
