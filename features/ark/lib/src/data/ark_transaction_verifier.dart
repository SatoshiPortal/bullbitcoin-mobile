import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

/// Wallet-free public codec adapter. These are internally consistent PSBT
/// facts, not chain membership or a script/signature validity proof. Ark checks
/// the expected inputs, destination, values and its durable fee authorization.
final class ArkTransactionVerifier implements ArkTransactionVerifierPort {
  const ArkTransactionVerifier();

  @override
  Future<Result<ArkTransactionFacts, ArkWalletFailure>> inspectTransaction({
    required String transactionHex,
    required String signedPsbt,
    required BitcoinNetwork network,
  }) async {
    final bytes = _hex(transactionHex);
    if (bytes == null) return const Err(ArkValidationFailure());
    final result = inspectBitcoinPsbt(signedPsbt);
    if (result case Err()) return const Err(ArkValidationFailure());
    if (result case Ok(:final value)) {
      final finalTx = value.finalTransaction;
      if (finalTx == null) return const Err(ArkValidationFailure());
      try {
        final decoded = decodeBitcoinTransaction(bytes);
        // Txid ignores SegWit witnesses. Compare every consensus byte, not a
        // subset of fields or just the unchanged txid, before copying evidence.
        if (decoded.txid != finalTx.txid ||
            !_equal(decoded.bytes, finalTx.bytes)) {
          return const Err(ArkValidationFailure());
        }
        return Ok(
          ArkTransactionFacts(
            txid: decoded.txid,
            psbtTxid: finalTx.txid,
            inputs: [
              for (final input in value.inputs)
                ArkTransactionInput(
                  outpoint: '${input.outpoint.txId}:${input.outpoint.vout}',
                  amount: Sats.fromInt(input.prevoutValueSat),
                  finalWitness: input.hasFinalWitness,
                ),
            ],
            outputs: _outputs(value.outputs, network),
            fee: Sats.fromInt(value.feeSat),
          ),
        );
      } on FormatException {
        return const Err(ArkValidationFailure());
      }
    }
    return const Err(ArkValidationFailure());
  }

  @override
  Future<Result<ArkBoardPsbtFacts, ArkWalletFailure>> inspectBoardPsbt({
    required String unfinalisedPsbt,
    required BitcoinNetwork network,
  }) async {
    switch (inspectBitcoinPsbt(unfinalisedPsbt)) {
      case Err():
        return const Err(ArkValidationFailure());
      case Ok(:final value):
        try {
          final decoded = decodeBitcoinPsbt(unfinalisedPsbt);
          final signed = value.inputs.any(
            (i) =>
                i.hasFinalFields ||
                i.hasPartialSignatures ||
                i.hasTaprootKeySignature ||
                i.hasTaprootScriptSignatures,
          );
          final segwit =
              value.inputs.isNotEmpty &&
              value.inputs.every((i) {
                final script = i.prevoutScriptPubkey;
                return script.length == 22 && script[0] == 0 && script[1] == 20;
              }) &&
              decoded.inputDetails.every((input) => input.scriptSig.isEmpty);
          return Ok(
            ArkBoardPsbtFacts(
              unsignedTxid: value.unsignedTxid,
              finalised: signed,
              nativeSegwitInputs: segwit,
              outputs: _outputs(value.outputs, network),
            ),
          );
        } on FormatException {
          return const Err(ArkValidationFailure());
        }
    }
  }

  static List<ArkTransactionOutput> _outputs(
    List<DecodedBitcoinOutput> outputs,
    BitcoinNetwork network,
  ) => [
    for (final output in outputs)
      ArkTransactionOutput(
        scriptPubkey: _toHex(output.scriptPubkey),
        address: switch (bitcoinScriptAddress(output.scriptPubkey, network)) {
          Ok(:final value) => value,
          Err() => null,
        },
        amount: Sats.fromInt(output.valueSat),
      ),
  ];
  static List<int>? _hex(String value) {
    if (value.isEmpty ||
        value.length.isOdd ||
        value.length > 8000000 ||
        !RegExp(r'^[0-9a-fA-F]+$').hasMatch(value)) {
      return null;
    }
    return [
      for (var index = 0; index < value.length; index += 2)
        int.parse(value.substring(index, index + 2), radix: 16),
    ];
  }

  static String _toHex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  static bool _equal(List<int> a, List<int> b) =>
      a.length == b.length &&
      Iterable.generate(a.length).every((i) => a[i] == b[i]);
}
