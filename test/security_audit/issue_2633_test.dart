import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2633
// Finding: Duplicate watch-only imports check only default wallets before upsert.
// Regression test for the fix.
void main() {
  group('Security audit #2633 duplicate watch-only import', () {
    test('duplicate checks include imported wallets and use typed error', () {
      final source = File(
        'lib/core/wallet/data/repositories/wallet_repository.dart',
      ).readAsStringSync();
      final importDescriptor = source.substring(
        source.indexOf('importDescriptor'),
      );
      final importXpub = source.substring(
        source.indexOf('importWatchOnlyXpub'),
      );
      // The duplicate check reads every wallet before inserting. It calls the
      // repository-internal reader rather than the public `getWallets()`,
      // which now returns a Result and is the try/catch boundary (#1895) —
      // the security property asserted here is the check, not the name.
      expect(importDescriptor, contains('_readWallets()'));
      expect(importXpub, contains('_readWallets()'));
      expect(source, contains('WalletAlreadyExistsException'));
      expect(
        File(
          'lib/core/wallet/data/datasources/wallet_metadata_datasource.dart',
        ).readAsStringSync(),
        contains('insertOnConflictUpdate'),
      );
    });
  });
}
