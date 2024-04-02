import 'dart:typed_data';

import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:lwk_dart/lwk_dart.dart' as lwk;

class WalletSensitiveTx {
  Future<(String?, Err?)> signTx({
    required String unsignedPSBT,
    required bdk.Wallet signingWallet,
  }) async {
    try {
      final psbt = bdk.PartiallySignedTransaction(psbtBase64: unsignedPSBT);
      final signedPSBT = await signingWallet.sign(psbt: psbt);
      return (signedPSBT.psbtBase64, null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while signing transaction',
          solution: 'Please try again.',
        )
      );
    }
  }

  Future<(Uint8List?, Err?)> signLiquidTx({
    required String unsignedPSET,
    required lwk.Wallet signingWallet,
    required String mnemonic,
    required BBNetwork network,
  }) async {
    try {
      final txBytes = await signingWallet.sign(
        network: network == BBNetwork.LMainnet ? lwk.Network.Mainnet : lwk.Network.Testnet,
        pset: unsignedPSET,
        mnemonic: mnemonic,
      );
      return (txBytes, null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while signing transaction',
          solution: 'Please try again.',
        )
      );
    }
  }

  Future<(Transaction?, Err?)> buildBumpFeeTx({
    required Transaction tx,
    required double feeRate,
    required bdk.Wallet signingWallet,
    required bdk.Wallet pubWallet,
  }) async {
    try {
      var txBuilder = bdk.BumpFeeTxBuilder(
        txid: tx.txid,
        feeRate: feeRate,
      );
      txBuilder = txBuilder.enableRbf();
      final txResult = await txBuilder.finish(pubWallet);
      final signedPSBT = await signingWallet.sign(psbt: txResult.psbt);

      final txDetails = txResult.txDetails;

      final newTx = Transaction(
        txid: txDetails.txid,
        received: txDetails.received,
        sent: txDetails.sent,
        fee: txDetails.fee ?? 0,
        height: txDetails.confirmationTime?.height,
        timestamp: txDetails.confirmationTime?.timestamp ?? 0,
        label: tx.label,
        toAddress: tx.toAddress,
        psbt: signedPSBT.psbtBase64,
      );
      return (newTx, null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while building transaction',
          solution: 'Please try again.',
        )
      );
    }
  }
}
