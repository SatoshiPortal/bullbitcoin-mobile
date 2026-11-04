import 'package:bull_sdk/bdk.dart' as bdk;

/// Reads a supplied PSBT without opening persisted wallet state.
class WalletPsbtInspection {
  const WalletPsbtInspection();

  Future<int> decodeTxSize(String psbtString) async {
    final psbt = bdk.Psbt(psbtBase64: psbtString);
    final size = psbt.extractTx().vsize();
    return size.toInt();
  }

  Future<int> getFeeAmount(String psbtString) async {
    final psbt = bdk.Psbt(psbtBase64: psbtString);
    final fee = psbt.fee();
    return fee;
  }

  Future<int> getAmountSentToAddress(
    String psbtString,
    String address, {
    required bool isTestnet,
  }) async {
    final psbt = bdk.Psbt(psbtBase64: psbtString);
    final tx = psbt.extractTx();
    final outputs = tx.output();
    int totalAmount = 0;
    for (final output in outputs) {
      final scriptPubkey = output.scriptPubkey;
      final outputAddress = bdk.Address.fromScript(
        script: bdk.Script(rawOutputScript: scriptPubkey.toBytes()),
        network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
      );
      if (outputAddress.toString() == address) {
        totalAmount += output.value.toSat();
      }
    }
    return totalAmount;
  }
}
