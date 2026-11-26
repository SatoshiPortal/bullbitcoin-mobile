import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D92: nothing exported by `package:secrets/storage.dart` hands an Ark child's
/// words to a caller-chosen function. Renewal does not run headless.
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
}
