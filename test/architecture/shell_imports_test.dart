import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('the Send workspace member does not import the app shell', () {
    final sources = Directory('features/send/lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final source in sources) {
      expect(
        source.readAsStringSync(),
        isNot(contains('package:bb_mobile/')),
        reason: source.path,
      );
    }
  });

  test('the shell supplies service status with owner capabilities', () {
    final shell = parseString(
      content: File('lib/locator.dart').readAsStringSync(),
    ).unit;

    expect(
      shell.directives
          .whereType<ImportDirective>()
          .map((directive) => directive.uri.stringValue)
          .whereType<String>()
          .where(
            (uri) => const {
              'get_default_wallet_network_usecase.dart',
              'is_tor_required_usecase.dart',
              'wallet_repository.dart',
              'wallet_facade.dart',
            }.contains(p.basename(uri)),
          ),
      isEmpty,
    );
  });

  test('features and packages depend on owners, never on the shell', () {
    final root = Directory.current.path;
    final violations = <String>[];
    for (final directory in ['lib/features', 'features', 'packages']) {
      for (final file in Directory(
        directory,
      ).listSync(recursive: true).whereType<File>()) {
        final path = p.relative(file.path, from: root);
        if (!path.endsWith('.dart') ||
            path.split(p.separator).any((part) => part.startsWith('.'))) {
          continue;
        }
        // Only production libraries; test/tool imports have separate contracts.
        if (!path.startsWith('lib/features/') &&
            !RegExp(r'^(features|packages)/[^/]+/lib/').hasMatch(path)) {
          continue;
        }
        final unit = parseString(content: file.readAsStringSync()).unit;
        for (final directive in unit.directives) {
          final uris = <String?>[
            if (directive is UriBasedDirective) directive.uri.stringValue,
            if (directive is ImportDirective)
              ...directive.configurations.map((c) => c.uri.stringValue),
            if (directive is ExportDirective)
              ...directive.configurations.map((c) => c.uri.stringValue),
            if (directive is PartOfDirective) directive.uri?.stringValue,
          ];
          for (final uri in uris.whereType<String>()) {
            final String target;
            if (uri.startsWith('package:bb_mobile/')) {
              if (path.startsWith('packages/') ||
                  path.startsWith('features/')) {
                violations.add('$path -> $uri (package imports app)');
                continue;
              }
              target = p.join(
                root,
                'lib',
                uri.substring('package:bb_mobile/'.length),
              );
            } else if (Uri.parse(uri).scheme == 'file') {
              target = Uri.parse(uri).toFilePath();
            } else if (Uri.parse(uri).hasScheme) {
              continue;
            } else {
              target = p.normalize(p.join(root, p.dirname(path), uri));
            }
            if (!path.startsWith('lib/') &&
                p.isWithin(p.join(root, 'lib'), target)) {
              violations.add('$path -> $uri (package imports app)');
              continue;
            }
            if (p.dirname(target) != p.join(root, 'lib')) continue;
            violations.add('$path -> ${p.basename(target)}');
          }
        }
      }
    }
    expect(violations, isEmpty);
  });
}
