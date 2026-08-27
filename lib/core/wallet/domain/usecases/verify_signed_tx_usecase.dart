import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:convert/convert.dart';
import 'package:meta/meta.dart';

/// Checks that a signed Bitcoin transaction preserves the unsigned PSBT's
/// version, locktime, inputs, sequences, outputs, amounts, and scripts.
/// Signatures and witness data may change; the transaction skeleton may not.
class VerifySignedTxUsecase {
  @useResult
  Future<Result<void, SignedTransactionVerificationFailure>> execute({
    required String unsignedPsbt,
    required String signedTransaction,
    bool isPsbt = false,
  }) async {
    final BitcoinTx signed;
    final BitcoinTx intended;
    try {
      signed = isPsbt
          ? await BitcoinTx.fromPsbt(signedTransaction)
          : await BitcoinTx.fromBytes(hex.decode(signedTransaction));
      intended = await BitcoinTx.fromPsbt(unsignedPsbt);
    } on Exception catch (error) {
      return Err(
        SignedTransactionVerificationFailure(
          'Could not decode the signed transaction: $error',
        ),
      );
    }

    if (!_isSameUnsignedTransaction(signed, intended)) {
      return const Err(
        SignedTransactionVerificationFailure(
          'The signed transaction does not match the confirmed transaction',
        ),
      );
    }
    return const Ok(null);
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
