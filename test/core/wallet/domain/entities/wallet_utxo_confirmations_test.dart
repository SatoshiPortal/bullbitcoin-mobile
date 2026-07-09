import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart'
    show confirmationsFromTip;
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Exercises the real helper used by `BdkWalletDatasource.getUtxos` (D2):
  // `max(0, tip - height + 1)`, with unconfirmed utxos reporting 0.
  group('confirmationsFromTip — max(0, tip - height + 1)', () {
    test('a utxo in the tip block has 1 confirmation', () {
      expect(confirmationsFromTip(tip: 100, height: 100), 1);
    });

    test('counts depth correctly below the tip', () {
      expect(confirmationsFromTip(tip: 100, height: 96), 5);
    });

    test('unconfirmed utxo (no height) reports 0', () {
      expect(confirmationsFromTip(tip: 100, height: null), 0);
    });

    test('clamps to 0 when tip < height (reorg / mid-sync)', () {
      expect(confirmationsFromTip(tip: 100, height: 105), 0);
    });
  });

  group('WalletUtxo.isConfirmed (threshold 1)', () {
    WalletUtxo build(int confirmations) => WalletUtxo.bitcoin(
      walletId: 'w',
      txId: 'tx',
      vout: 0,
      scriptPubkey: Uint8List(0),
      amountSat: BigInt.from(1000),
      address: 'addr',
      confirmations: confirmations,
    );

    test('0 confirmations → not confirmed (pending)', () {
      expect(build(0).isConfirmed, isFalse);
    });

    test('1+ confirmations → confirmed', () {
      expect(build(1).isConfirmed, isTrue);
      expect(build(6).isConfirmed, isTrue);
    });

    test('defaults to 0 confirmations / unconfirmed', () {
      final utxo = WalletUtxo.bitcoin(
        walletId: 'w',
        txId: 'tx',
        vout: 0,
        scriptPubkey: Uint8List(0),
        amountSat: BigInt.from(1000),
        address: 'addr',
      );
      expect(utxo.confirmations, 0);
      expect(utxo.isConfirmed, isFalse);
    });
  });
}
