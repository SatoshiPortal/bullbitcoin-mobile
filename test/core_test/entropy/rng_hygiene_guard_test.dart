import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level guards against the RNG failure classes documented in
/// Block's Coldcard disclosure (predictable fallback binding, narrow
/// reseed pipe, call-site drift). These invariants held at review time;
/// this test makes them fail loudly instead of silently when a future
/// refactor moves a call site or weakens a binding.
void main() {
  late final List<File> libFiles;

  setUpAll(() {
    libFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.contains('lib/generated/'))
        .toList();
    expect(libFiles, isNotEmpty, reason: 'expected to run from package root');
  });

  Iterable<String> filesContaining(Pattern pattern) sync* {
    for (final file in libFiles) {
      if (file.readAsStringSync().contains(pattern)) {
        yield file.path.replaceAll(r'\', '/');
      }
    }
  }

  test('fresh mnemonics are generated in exactly one place', () {
    // Coldcard's bug shipped when a refactor drifted callers from the
    // hardware RNG wrapper to a broken binding. Any new generation call
    // site must go through MnemonicGenerator or consciously amend this.
    expect(filesContaining('Mnemonic(wordCount').toList(), [
      'lib/core/seed/data/services/mnemonic_generator.dart',
    ]);
  });

  test('only the generator and the locator touch the entropy pool from '
      'outside the entropy module', () {
    final importers = filesContaining(
      "entropy_pool.dart'",
    ).where((p) => !p.startsWith('lib/core/entropy/')).toList()..sort();
    expect(importers, [
      'lib/core/seed/data/services/mnemonic_generator.dart',
      'lib/core/seed/seed_locator.dart',
    ]);
  });

  test('mandatory gate can only be fed by the collector and the generator', () {
    final callers = filesContaining('.mixMandatory(').toList()..sort();
    expect(callers, [
      'lib/core/entropy/data/services/entropy_collector.dart',
      'lib/core/seed/data/services/mnemonic_generator.dart',
    ]);
  });

  test('no non-secure Random anywhere in the entropy or seed modules', () {
    final insecure = RegExp(r'\bRandom\((?!\))|\bRandom\(\d');
    for (final file in libFiles.where(
      (f) =>
          f.path.contains('lib/core/entropy/') ||
          f.path.contains('lib/core/seed/'),
    )) {
      final source = file.readAsStringSync();
      for (final match in RegExp(r'\bRandom[.(]').allMatches(source)) {
        final snippet = source.substring(
          match.start,
          (match.start + 14).clamp(0, source.length),
        );
        expect(
          snippet.startsWith('Random.secure'),
          isTrue,
          reason:
              'non-secure Random in ${file.path}: "$snippet" — '
              'seed/entropy code must only use Random.secure()',
        );
      }
      expect(
        insecure.hasMatch(source),
        isFalse,
        reason: 'seeded Random(...) constructor in ${file.path}',
      );
    }
  });

  test('production wiring cannot weaken the pool configuration', () {
    // The locator must construct EntropyPool with defaults: overriding
    // strengthenBudget (the deterministic test mode) belongs to tests only.
    final overriders = filesContaining('strengthenBudget')
        .where((p) => p != 'lib/core/entropy/data/services/entropy_pool.dart')
        .toList();
    expect(overriders, isEmpty);
    final locator = File(
      'lib/core/entropy/entropy_locator.dart',
    ).readAsStringSync();
    expect(locator.contains('EntropyPool()'), isTrue);
  });
}
