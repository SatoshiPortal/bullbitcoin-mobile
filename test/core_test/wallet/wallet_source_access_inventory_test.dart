import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persisted wallet facades stay behind the approved data boundary', () {
    const approvedFiles = {
      'lib/core/wallet/data/datasources/bdk_wallet_datasource.dart',
      'lib/core/wallet/data/datasources/lwk_wallet_datasource.dart',
      'lib/core/wallet/data/datasources/lwk_facade.dart',
    };
    final violations = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (!source.contains('BdkFacade.') && !source.contains('LwkFacade.')) {
        continue;
      }
      if (!approvedFiles.contains(entity.path)) violations.add(entity.path);
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Persisted SDK wallet access must go through the coordinated data boundary.',
    );
  });

  test('each persisted source call is immediately guarded by the coordinator', () {
    const guardedCalls = {
      'lib/core/wallet/data/payjoin_wallet_adapter.dart': [
        '_wallet.getUtxos(',
        '_wallet.createIsMineChecker(',
        '_wallet.createOutpointIsMineChecker(',
        '_wallet.createPsbtSigner(',
        '_wallet.signPsbt(',
      ],
      'lib/core/wallet/data/repositories/bitcoin_wallet_repository.dart': [
        '_bdkWallet.buildPsbt(',
        '_bdkWallet.signPsbt(',
        '_bdkWallet.isMine(',
        '_bdkWallet.isAddressMine(',
        '_bdkWallet.createUnsignedReplaceByFeePsbt(',
      ],
      'lib/core/wallet/data/repositories/liquid_wallet_repository.dart': [
        '_lwkWallet.buildPset(',
        '_lwkWallet.getLbtcUtxoCount(',
        '_lwkWallet.consolidate(',
        '_lwkWallet.signPset(',
        '_lwkWallet.getAmountSentToAddress(',
      ],
      'lib/core/wallet/data/repositories/wallet_address_repository.dart': [
        '_bdkWallet.getLastRevealedAddressOrNew(',
        '_lwkWallet.getLastUnusedAddress(',
        '_bdkWallet.getNewAddress(',
        '_bdkWallet.getLastRevealedAddressIndex(',
        '_lwkWallet.getLastUnusedAddressIndex(',
      ],
      'lib/core/wallet/data/repositories/wallet_repository.dart': [
        '_lwkWallet.getBalance(',
        '_bdkWallet.getBalance(',
        '_lwkWallet.getAmountSentToAddress(',
      ],
      'lib/core/wallet/data/repositories/wallet_transaction_repository_impl.dart':
          ['.getTransactions('],
      'lib/core/wallet/data/repositories/wallet_utxo_repository_impl.dart': [
        '_bdkWalletDatasource.getUtxos(',
        '_lwkWalletDatasource.getUtxos(',
      ],
    };

    final uncoordinated = <String>[];
    for (final entry in guardedCalls.entries) {
      final lines = File(entry.key).readAsLinesSync();
      for (final call in entry.value) {
        final index = lines.indexWhere((line) => line.contains(call));
        if (index < 0 ||
            !lines
                .sublist(index < 30 ? 0 : index - 30, index + 1)
                .any((line) => line.contains('runExclusive'))) {
          uncoordinated.add('${entry.key}: $call');
        }
      }
    }

    expect(
      uncoordinated,
      isEmpty,
      reason:
          'Every persisted BDK/LWK call site must be guarded by the coordinator.',
    );
  });
}
