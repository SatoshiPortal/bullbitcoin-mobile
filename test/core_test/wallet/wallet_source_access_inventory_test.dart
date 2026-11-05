import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persisted wallet facades stay behind the approved data boundary', () {
    final violations = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (!source.contains('BdkFacade.') && !source.contains('LwkFacade.')) {
        continue;
      }
      violations.add(entity.path);
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Persisted SDK wallet access must go through the coordinated data boundary.',
    );
  });

  test(
    'each persisted source call is immediately guarded by the coordinator',
    () {
      const guardedCalls = {
        'lib/payjoin_wallet_adapters.dart': [
          '_wallet.getUtxos(',
          '_wallet.createIsMineChecker(',
          '_wallet.createOutpointIsMineChecker(',
          // Both paths into _signPsbt, which reads the wallet through
          // _wallet.addOwnDerivations before secrets signs.
          'return _signPsbt(psbt, metadata, network);',
          '(psbt) => _signPsbt(psbt, metadata, network),',
        ],
        'packages/wallet/lib/src/data/bitcoin_wallet_repository.dart': [
          '_bdkWallet.buildPsbt(',
          '_signing.signPsbt(',
          '_bdkWallet.isMine(',
          '_bdkWallet.isAddressMine(',
          '_signing.bumpFee(',
        ],
        'packages/wallet/lib/src/data/liquid_wallet_repository.dart': [
          '_lwkWallet.buildPset(',
          '_lwkWallet.getLbtcUtxoCount(',
          '_lwkWallet.consolidate(',
          '_signing.signPset(',
          '_lwkWallet.getAmountSentToAddress(',
        ],
        'packages/wallet/lib/src/data/wallet_address_repository.dart': [
          '_bdkWallet.getLastRevealedAddressOrNew(',
          '_lwkWallet.getLastUnusedAddress(',
          '_bdkWallet.getNewAddress(',
          '_bdkWallet.getLastRevealedAddressIndex(',
          '_lwkWallet.getLastUnusedAddressIndex(',
        ],
        'packages/wallet/lib/src/data/wallet_repository.dart': [
          '_lwkWallet.getBalance(',
          '_bdkWallet.getBalance(',
          '_lwkWallet.getAmountSentToAddress(',
        ],
        'packages/wallet/lib/src/data/wallet_transaction_reader.dart': [
          '.getTransactions(',
        ],
        'packages/wallet/lib/src/data/wallet_utxo_repository_impl.dart': [
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
    },
  );
}
