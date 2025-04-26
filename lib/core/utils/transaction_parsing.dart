import 'package:bb_mobile/core/utils/address_script_conversions.dart';
import 'package:bb_mobile/core/wallet/data/models/transaction_output_model.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:flutter/foundation.dart';

class TransactionParsing {
  static Future<List<TransactionOutputModel>> extractSpentUtxosFromPsbt(
    String psbt, {
    required bool isTestnet,
  }) async {
    debugPrint('Extracting inputs from psbt: $psbt');
    final tx = await bdk.PartiallySignedTransaction.fromString(psbt);
    final inputs = await tx.extractTx().input();
    final txInputs = await Future.wait(
      inputs.map((input) async {
        return TransactionOutputModel.bitcoin(
          txId: input.previousOutput.txid,
          vout: input.previousOutput.vout,
          scriptPubkey: input.scriptSig.bytes,
          address:
              await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
            input.scriptSig.bytes,
            isTestnet: isTestnet,
          ),
        );
      }),
    );
    debugPrint('Extracted inputs: $inputs');
    return txInputs;
  }

  static Future<String> getTxIdFromPsbt(String psbt) async {
    final tx = await bdk.PartiallySignedTransaction.fromString(psbt);
    return tx.extractTx().txid();
  }

  static Future<String> getTxIdFromTransactionBytes(
    Uint8List transactionBytes,
  ) async {
    final tx = await bdk.Transaction.fromBytes(
      transactionBytes: transactionBytes,
    );
    return tx.txid();
  }

  static Future<BigInt> getAmountReceivedFromTransactionBytes(
    Uint8List transactionBytes, {
    required String address,
    required bool isTestnet,
  }) async {
    final tx = await bdk.Transaction.fromBytes(
      transactionBytes: transactionBytes,
    );

    final outputs = await tx.output();
    BigInt totalAmount = BigInt.zero;
    for (final output in outputs) {
      final scriptPubkey = output.scriptPubkey;
      final outputAddress = await bdk.Address.fromScript(
        script: bdk.ScriptBuf(bytes: scriptPubkey.bytes),
        network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
      );
      if (outputAddress.asString() == address) {
        totalAmount += output.value;
      }
    }

    return totalAmount;
  }
}
