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
          'Future<String> createWallet(',
          'Future<Wallet> _createdWallet(',
        ),
        method(
          'Future<Result<Wallet, ImportWatchOnlyFailure>> _importWatchOnly(',
          '  @override',
        ),
      ];
      for (final path in creationPaths) {
        expect(path, contains('await _provision(metadata);'));
        expect(path, isNot(contains('_walletRegistrations.store(')));
      }
      // Imported and catalog-only wallets count without opening native stores.
      for (final path in creationPaths.skip(1)) {
        expect(path, contains('_walletRegistrations.fetchAll()'));
        expect(
          path.indexOf('_walletRegistrations.fetchAll()'),
          lessThan(path.indexOf('await _provision(metadata);')),
        );
        expect(
          path,
          contains('return const Err(WalletAlreadyExistsFailure())'),
        );
      }
      final provision = method(
        'Future<void> _provision(',
        'Future<void> _createNative(',
      );
      expect(provision, contains('_walletRegistrations.fetch(metadata.id)'));
      expect(provision, contains('WalletAlreadyExistsException(metadata.id)'));
      expect(
        provision,
        contains('await _walletRegistrations.insert(metadata);'),
      );
      expect(
        provision.indexOf('_walletRegistrations.insert(metadata)'),
        lessThan(provision.indexOf('await _createNative(metadata)')),
      );
      expect(provision, isNot(contains('_walletRegistrations.store(')));
      final inventory = File(
        'packages/secrets/lib/src/data/inventory_repository.dart',
      ).readAsStringSync();
      final claim = inventory.substring(
        inventory.indexOf('Future<Result<void, SecretFailure>> register('),
        inventory.indexOf(
          'Future<Result<void, SecretFailure>> updateProperties(',
        ),
      );
      expect(claim, contains('insertReturningOrNull'));
      expect(claim, contains('DoNothing(target:'));
      expect(claim, contains('WalletAlreadyRegisteredFailure'));
    });
  });
}
