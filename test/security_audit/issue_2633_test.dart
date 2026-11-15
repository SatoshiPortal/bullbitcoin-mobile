import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2633
// Finding: Duplicate watch-only imports check only default wallets before upsert.
// Regression test for the fix.
void main() {
  group('Security audit #2633 duplicate watch-only import', () {
    test('duplicate checks include imported wallets and use typed error', () {
      final source = File('lib/features/wallet/data/wallet_repository.dart')
          .readAsStringSync();
      String method(String start, String end) => source.substring(
        source.indexOf(start),
        source.indexOf(end, source.indexOf(start)),
      );
      final creationPaths = [
        method(
          'Future<Wallet> createWallet(',
          'Future<Wallet> importDescriptor(',
        ),
        method(
          'Future<Wallet> importDescriptor(',
          'Future<Wallet> importWatchOnlyXpub(',
        ),
        method('Future<Wallet> importWatchOnlyXpub(', '  @useResult'),
      ];
      for (final path in creationPaths) {
        expect(path, contains('await _provision(metadata);'));
        expect(path, isNot(contains('_walletMetadataDatasource.store(')));
      }
      // Imported and catalog-only wallets count without opening native stores.
      for (final path in creationPaths.skip(1)) {
        expect(path, contains('_walletMetadataDatasource.fetchAll()'));
        expect(
          path.indexOf('_walletMetadataDatasource.fetchAll()'),
          lessThan(path.indexOf('await _provision(metadata);')),
        );
        expect(path, contains('WalletAlreadyExistsException(metadata.id)'));
      }
      final provision = method(
        'Future<void> _provision(',
        'Future<void> _createNative(',
      );
      expect(
        provision,
        contains('_walletMetadataDatasource.fetch(metadata.id)'),
      );
      expect(provision, contains('WalletAlreadyExistsException(metadata.id)'));
      expect(
        provision,
        contains('await _walletMetadataDatasource.insert(metadata);'),
      );
      expect(
        provision.indexOf('_walletMetadataDatasource.insert(metadata)'),
        lessThan(provision.indexOf('await _createNative(metadata)')),
      );
      expect(provision, isNot(contains('_walletMetadataDatasource.store(')));
      final datasource = File(
        'lib/features/wallet/data/wallet_metadata_datasource.dart',
      ).readAsStringSync();
      final claim = datasource.substring(
        datasource.indexOf('Future<void> insert('),
        datasource.indexOf('Future<void> store('),
      );
      expect(claim, contains('.insert(metadata.toSqlite())'));
      expect(claim, isNot(contains('insertOnConflictUpdate')));
      expect(claim, contains('SQLITE_CONSTRAINT_PRIMARYKEY'));
      expect(claim, contains('WalletAlreadyExistsException(metadata.id)'));
    });
  });
}
