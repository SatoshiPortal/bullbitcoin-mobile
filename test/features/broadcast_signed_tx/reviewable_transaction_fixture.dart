import 'package:bb_mobile/core/transactions/domain/entities/bitcoin_transaction.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/reviewable_transaction.dart';

/// A Bitcoin review with one resolved input of [inputSat] and one output of
/// [outputSat].
ReviewableTransaction bitcoinReview({
  required int inputSat,
  required int outputSat,
}) => ReviewableTransaction(
  transaction: BitcoinTransaction(
    txid: 'tx',
    version: 2,
    size: 200,
    vsize: 141,
    locktime: 0,
    inputs: const [
      BitcoinTxInput(previousTxId: 'parent', previousVout: 0, sequence: 0),
    ],
    outputs: [
      BitcoinTxOutput(
        valueSat: outputSat,
        index: 0,
        scriptPubKeyHex: '',
        scriptPubKeyBytes: const [],
      ),
    ],
  ),
  resolvedInputs: [
    ResolvedInput(valueSat: inputSat, previousTxId: 'parent', previousVout: 0),
  ],
);
