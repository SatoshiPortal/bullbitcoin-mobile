import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// D105: the library that hands the dedicated Ark BIP85 child over has one
/// importer in the whole app, the trusted renewal client. Neither the worker,
/// nor any feature, nor the shell may read that child: they can only call the
/// renewal operation on the client it builds.
void main() {
  const importer = 'features/ark/lib/src/data/ark_renewal_client.dart';
  final root = Directory.current.path;

  Iterable<File> libraryFiles() sync* {
    for (final base in ['lib', 'packages', 'features']) {
      final directory = Directory(p.join(root, base));
      if (!directory.existsSync()) continue;
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final relative = p.relative(entity.path, from: root);
        final parts = p.split(relative);
        if (parts.contains('build') ||
            parts.contains('.dart_tool') ||
            parts.contains('test') ||
            parts.contains('generated')) {
          continue;
        }
        if (base != 'lib' && !parts.contains('lib')) continue;
        yield entity;
      }
    }
  }

  test(
    'only the trusted renewal client imports the restricted secrets library',
    () {
      final importers = [
        for (final file in libraryFiles())
          if (file.readAsStringSync().contains(
            RegExp(r'''['"]package:secrets/ark_renewal\.dart['"]'''),
          ))
            p.relative(file.path, from: root).replaceAll(r'\', '/'),
      ];
      expect(importers, [importer]);
    },
  );

  test('the public secrets libraries do not export the restricted one', () {
    for (final barrel in [
      'packages/secrets/lib/secrets.dart',
      'packages/secrets/lib/storage.dart',
      'packages/secrets/lib/custody.dart',
      'packages/secrets/lib/migration.dart',
      'packages/secrets/lib/metadata_backup.dart',
      'packages/secrets/lib/testing.dart',
      'packages/secrets/lib/bip85.dart',
    ]) {
      final source = File(p.join(root, barrel)).readAsStringSync();
      expect(source, isNot(contains('ark_renewal_secrets')), reason: barrel);
      expect(source, isNot(contains('ArkRenewalSecrets')), reason: barrel);
    }
  });

  test('the trusted client keeps the child out of logs and results', () {
    final source = File(p.join(root, importer)).readAsStringSync();
    expect(source, isNot(contains('log.')));
    expect(source, isNot(contains('print(')));
    // The words reach the native opener only through the port's callback.
    expect(source, isNot(contains('Ok(child')));
    expect(source, isNot(contains('Ok(mnemonic')));
  });

  test(
    'no public type of the trusted client can hand the words to a caller',
    () {
      final source = File(p.join(root, importer)).readAsStringSync();
      // The port that carries the words is private: only the native opener the
      // client was built with can reach it.
      expect(source, contains('final class _ChildProvider'));
      expect(source, isNot(contains('class ArkRenewalChildProvider')));
      for (final declaration in RegExp(
        r'^(?:final |abstract |base |sealed )*class (\w+)',
        multiLine: true,
      ).allMatches(source).map((match) => match.group(1)!)) {
        if (declaration.startsWith('_')) continue;
        expect(
          ['ArkRenewalAdmission', 'ArkBackgroundRenewal'],
          contains(declaration),
          reason: 'public class $declaration',
        );
      }
      // The public classes carry no word: no mnemonic in any signature.
      final publicPart = source.split('final class _ChildProvider').first;
      expect(publicPart, isNot(contains('mnemonic')));
      expect(publicPart, isNot(contains('String Function')));
    },
  );
}
