import 'dart:typed_data';

import 'package:bb_mobile/features/coins/domain/wallet_utxo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
