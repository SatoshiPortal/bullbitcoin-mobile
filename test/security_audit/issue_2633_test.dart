import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2633
// Finding: Duplicate watch-only imports check only default wallets before upsert.
// Regression test for the fix.
void main() {
  group('Security audit #2633 duplicate watch-only import', () {
    test('duplicate checks include imported wallets and use typed error', () {
      final source = File(
        'packages/provisioning/lib/src/wallet_provisioning.dart',
      ).readAsStringSync();
      String method(String start, String end) {
        final from = source.indexOf(start);
        expect(from, greaterThanOrEqualTo(0), reason: start);
        final to = source.indexOf(end, from);
        expect(to, greaterThan(from), reason: end);
        return source.substring(from, to);
      }

      final importWatchOnly = method(
        'Future<Result<void, WalletProvisioningFailure>> _importWatchOnly(',
        'Future<Result<bool, WalletProvisioningFailure>> _hasDefault(',
      );
      expect(importWatchOnly, contains('await _provision(account);'));
      expect(importWatchOnly, isNot(contains('_inventory.registerWallet(')));
      // Every account, imported or default, is checked by identifier before
      // anything is created, and a duplicate is a typed failure.
      final provision = method(
        'Future<Result<void, WalletProvisioningFailure>> _provision(',
        'Future<Result<void, SecretFailure>> _prepareProperties(',
      );
      expect(provision, contains('_inventory.findWallet(account.id)'));
      expect(
        provision,
        contains('return const Err(WalletProvisioningConflictFailure());'),
      );
      expect(
        provision.indexOf('_inventory.findWallet(account.id)'),
        lessThan(provision.indexOf('_native.prepareCreate(key)')),
      );
      expect(
        provision.indexOf('_inventory.registerWallet('),
        lessThan(provision.indexOf('_native.create(key)')),
      );
      expect(
        provision,
        contains('case Err(failure: WalletAlreadyRegisteredFailure()):'),
      );
      // The importers reach the catalog only through that provisioning step.
      final defaults = method(
        '  Future<Result<String, WalletProvisioningFailure>> createDefault(\n'
            '    Secret secret,\n'
            '    Network network, {\n'
            '    DateTime? birthday,\n'
            '  }) async {',
        '  @override\n  Future<Result<void, ParentCustodyFailure>> importMnemonic({',
      );
      expect(defaults, contains('await _provision(account)'));
      final mapping = File(
        'features/wallet_import/lib/src/domain/watch_only/'
        'import_watch_only_failure_mapping.dart',
      ).readAsStringSync();
      expect(
        mapping,
        contains(
          'WalletProvisioningConflictFailure() => const WalletAlreadyExistsFailure()',
        ),
      );
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
