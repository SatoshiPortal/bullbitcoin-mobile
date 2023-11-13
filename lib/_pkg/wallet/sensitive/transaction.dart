import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class WalletSensitiveTx {
  Future<(String?, Err?)> signTx({
    required String unsignedPSBT,
    required bdk.Wallet signingWallet,
  }) async {
    try {
      final psbt = bdk.PartiallySignedTransaction(psbtBase64: unsignedPSBT);
      final signedPSBT = await signingWallet.sign(psbt: psbt);
      return (signedPSBT.psbtBase64, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(Transaction?, Err?)> buildBumpFeeTx({
    required Transaction tx,
    required double feeRate,
    required bdk.Wallet signingWallet,
    required bdk.Wallet pubWallet,
  }) async {
    try {
      final txBuilder = bdk.BumpFeeTxBuilder(
        txid: tx.txid,
        feeRate: feeRate,
      );

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
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }
}
