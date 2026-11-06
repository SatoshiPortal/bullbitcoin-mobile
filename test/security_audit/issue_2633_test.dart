import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2633
// Finding: Duplicate watch-only imports check only default wallets before upsert.
// Regression test for the fix.
void main() {
  group('Security audit #2633 duplicate watch-only import', () {
    test('duplicate checks include imported wallets and use typed error', () {
      final source = File(
        'lib/features/wallet/data/wallet_repository.dart',
      ).readAsStringSync();
      final importDescriptor = source.substring(
        source.indexOf('importDescriptor'),
      );
      final importXpub = source.substring(
        source.indexOf('importWatchOnlyXpub'),
      );
      // Catalog-only provisioning rows count too: checking duplicates must not
      // require opening their native store or reading their balance.
      for (final method in [importDescriptor, importXpub]) {
        expect(method, contains('_walletMetadataDatasource.fetchAll()'));
        expect(
          method.indexOf('_walletMetadataDatasource.fetchAll()'),
          lessThan(method.indexOf('_walletMetadataDatasource.store(metadata)')),
        );
        expect(method, contains('WalletAlreadyExistsException(metadata.id)'));
      }
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
