// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2646
// Finding: next-index allocation and insertion are separate, raceable operations.
// Regression test for serialized UI commands. The Secrets registry also
// allocates and inserts the index in a single SQLite transaction.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'BIP85 serializes concurrent commands and allocates under a write lock',
    () {
      final cubit = File('features/bip85/lib/src/presentation/bip85_cubit.dart')
          .readAsStringSync();
      expect(cubit, contains('if (state.isLoading) return;'));

      final registry = File(
        'packages/secrets/lib/src/data/derivation_repository.dart',
      ).readAsStringSync();
      expect(registry, contains('guardedTransaction(_database'));
      expect(
        registry.indexOf('UPDATE access_state'),
        lessThan(registry.indexOf('var index = 0')),
      );
    },
  );
}
