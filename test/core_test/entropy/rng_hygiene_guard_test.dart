import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level tripwires for accidental RNG-path drift.
///
/// Behavioral tests remain the security evidence; these checks only make a
/// future call-site or dependency regression fail loudly.
void main() {
  late final List<File> libFiles;

  setUpAll(() {
    libFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.contains('lib/generated/'))
        .toList();
    expect(libFiles, isNotEmpty, reason: 'expected package-root execution');
  });

  Iterable<String> filesContaining(Pattern pattern) sync* {
    for (final file in libFiles) {
      if (file.readAsStringSync().contains(pattern)) {
        yield file.path.replaceAll(r'\', '/');
      }
    }
  }

  test('BDK random mnemonic generation is absent', () {
    expect(filesContaining('Mnemonic(wordCount').toList(), isEmpty);
  });

  test('the generator deterministically encodes explicit entropy', () {
    final generator = File(
      'lib/core/seed/data/services/mnemonic_generator.dart',
    ).readAsStringSync();

    expect(generator, contains('bdk.Mnemonic.fromEntropy'));
    expect(generator, contains('extractWithOsEntropy'));
  });

  test('removed environmental entropy sources do not return', () {
    for (final removedName in [
      'CpuJitterSource',
      'SystemStatsSource',
      'ImuSensorSource',
      'EntropyCollector',
    ]) {
      expect(filesContaining(removedName).toList(), isEmpty);
    }
  });

  test('entropy and seed code use no non-secure Random constructor', () {
    for (final file in libFiles.where(
      (file) =>
          file.path.contains('lib/core/entropy/') ||
          file.path.contains('lib/core/seed/'),
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
          reason: 'non-secure Random in ${file.path}: "$snippet"',
        );
      }
    }
  });

  test('production wiring uses the default OS provider', () {
    final locator = File(
      'lib/core/entropy/entropy_locator.dart',
    ).readAsStringSync();

    expect(locator, contains('OsRngSource()'));
    expect(locator, isNot(contains('provider:')));
  });

  test('onboarding has no human-entropy bypass', () {
    final screen = File(
      'lib/features/onboarding/ui/screens/onboarding_entropy_ceremony.dart',
    ).readAsStringSync();
    final cubit = File(
      'lib/features/onboarding/presentation/entropy_ceremony_cubit.dart',
    ).readAsStringSync();

    expect(screen, isNot(contains('Continue without drawing')));
    expect(screen, isNot(contains('onboardingEntropyCeremonySkip')));
    expect(cubit, isNot(contains('completeWithoutCeremony')));
  });
}
