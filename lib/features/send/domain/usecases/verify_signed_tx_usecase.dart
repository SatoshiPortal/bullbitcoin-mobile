import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:convert/convert.dart';

/// Checks that a transaction signed by a directly-connected hardware device
/// (Ledger, BitBox) is the transaction carried by the unsigned PSBT.
///
/// The confirm screen shows the pre-signing address and amount; without this
/// check, a compromised device or transport could return a transaction that
/// redirects funds or substitutes inputs, and the app would broadcast it while
/// the user still sees the intended details. Signing may add scriptSig and
/// witness data, but every other transaction field must remain identical.
class VerifySignedTxUsecase {
  Future<void> execute({
    required String unsignedPsbt,
    required String signedTxHex,
  }) async {
    final BitcoinTx signed;
    final BitcoinTx intended;
    try {
      signed = await BitcoinTx.fromBytes(hex.decode(signedTxHex));
      intended = await BitcoinTx.fromPsbt(unsignedPsbt);
    } catch (e) {
      throw VerifySignedTxException(
        'Could not decode the signed transaction: $e',
      );
    }

    if (!_isSameUnsignedTransaction(signed, intended)) {
      throw VerifySignedTxException(
        'The signed transaction does not match the confirmed transaction',
      );
    }
  }

  bool _isSameUnsignedTransaction(BitcoinTx signed, BitcoinTx intended) {
    if (signed.version != intended.version ||
        signed.locktime != intended.locktime) {
      return false;
    }

    final signedInputs = signed.vin;
    final intendedInputs = intended.vin;
    if (signedInputs.length != intendedInputs.length) return false;
    for (var i = 0; i < signedInputs.length; i++) {
      final signedInput = signedInputs[i];
      final intendedInput = intendedInputs[i];
      if (signedInput.txid != intendedInput.txid ||
          signedInput.vout != intendedInput.vout ||
          signedInput.sequence != intendedInput.sequence) {
        return false;
      }
    }

    final signedOutputs = signed.vout;
    final intendedOutputs = intended.vout;
    if (signedOutputs.length != intendedOutputs.length) return false;
    for (var i = 0; i < signedOutputs.length; i++) {
      final signedOutput = signedOutputs[i];
      final intendedOutput = intendedOutputs[i];
      if (signedOutput.value != intendedOutput.value) return false;
      final signedScript = signedOutput.scriptPubKey.bytes;
      final intendedScript = intendedOutput.scriptPubKey.bytes;
      if (signedScript.length != intendedScript.length) return false;
      for (var j = 0; j < signedScript.length; j++) {
        if (signedScript[j] != intendedScript[j]) return false;
      }
    }
    return true;
  }
}

class VerifySignedTxException extends BullException {
  VerifySignedTxException(super.message);
}
