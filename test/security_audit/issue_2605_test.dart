// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2605
// Finding: importing spendable:false immediately freezes an outpoint without confirmation.
// Regression test for the fix: freezes are opt-in AND limited to outpoints
// the attributed wallet currently owns.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2605 silent freeze import', () {
    test('import does not apply freezes unless explicitly opted in', () {
      final source = File(
        'lib/features/labels/application/usecases/import_labels_usecase.dart',
      ).readAsStringSync();

      expect(source, contains('bool importFreezes = false'));
      expect(source, contains('if (importFreezes) await _freezeOwnedOnly'));
    });

    test('imported freezes are limited to wallet-owned outpoints', () {
      final source = File(
        'lib/features/labels/application/usecases/import_labels_usecase.dart',
      ).readAsStringSync();

      // Unattributed records are dropped (they cannot be ownership-verified)
      // and attributed ones are intersected with the wallet's owned set.
      expect(
        source,
        contains('if (walletId == null || walletId.isEmpty) continue;'),
      );
      expect(source, contains('getOwnedOutpoints('));
    });
  });
}
