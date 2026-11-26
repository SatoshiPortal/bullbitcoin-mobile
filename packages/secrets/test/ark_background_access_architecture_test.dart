import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D92, D105: nothing exported by `package:secrets/storage.dart` hands an Ark
/// child's words to a caller. The background refresh goes through the restricted
/// `package:secrets/ark_renewal.dart` library, to a fixed consumer.
void main() {
  List<File> sources() =>
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList();

  test('no operation delivers words to a callback for a renewal', () {
    final offenders = [
      for (final file in sources())
        if (file.readAsStringSync().contains('withRenewalChild')) file.path,
    ];
    expect(offenders, isEmpty);
  });

  test('the background access library reads no seed and takes no callback', () {
    final source = File('lib/src/public/ark_background_access.dart')
        .readAsStringSync();
    for (final forbidden in [
      'secret_repository',
      'crypto/',
      'Deriver',
      'useMnemonic',
      'mnemonic',
      'Function(',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test(
    'the storage barrel exports the policy answer and nothing named renewal',
    () {
      final barrel = File('lib/storage.dart').readAsStringSync();
      expect(barrel, contains('ArkBackgroundAccess'));
      expect(barrel.toLowerCase(), isNot(contains('renewalauthority')));
    },
  );

  group('the restricted renewal library', () {
    late String source;
    setUp(() {
      source = File('lib/src/public/ark_renewal_secrets.dart')
          .readAsStringSync();
    });

    test('takes no caller-chosen callback and no free result type', () {
      expect(source, isNot(contains('withArkChild')));
      expect(source, isNot(contains('F extends Failure')));
      expect(source, isNot(contains('Future<Result<T, F>> Function(')));
    });

    test('hands the child to a fixed consumer interface', () {
      expect(source, contains('abstract interface class ArkChildConsumer'));
      expect(source, contains('consumeChild('));
    });

    test(
      'reads the parent seed only inside the one derivation of the child',
      () {
        // `describe` reads the stored entry for its public description and
        // returns nothing of the words; `useMnemonic` is the only exposure.
        expect('useMnemonic('.allMatches(source).length, 1);
        expect('Deriver.bip85.mnemonic('.allMatches(source).length, 1);
        for (final forbidden in [
          '.fetch(',
          'revealMnemonic',
          '.use(',
          'describeAll',
        ]) {
          expect(source, isNot(contains(forbidden)), reason: forbidden);
        }
      },
    );
  });
}
