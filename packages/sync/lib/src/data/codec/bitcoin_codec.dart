import 'dart:typed_data';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:primitives/primitives.dart';

import '../../domain/decoded_transactions.dart';
import '../../domain/sync_failure.dart';

/// A consensus-valid transaction never exceeds 4,000,000 weight units, so its
/// serialization never exceeds this many bytes.
const maxBitcoinTransactionBytes = 4000000;

/// PSBTs carry previous transactions; the bound keeps hostile input from
/// reaching the native parser, not from describing a valid PSBT.
const maxEncodedBitcoinPsbtLength = 16 * 1024 * 1024;

/// Decodes consensus bytes. Library function: no wallet is opened.
Result<DecodedBitcoinTransaction, SyncFailure> decodeBitcoinTransaction(
  List<int> bytes,
) {
  if (bytes.isEmpty || bytes.length > maxBitcoinTransactionBytes) {
    return const Err(SyncInvalidTransactionFailure());
  }
  try {
    final transaction = bdk.Transaction(
      transactionBytes: Uint8List.fromList(bytes),
    );
    try {
      return Ok(_decode(transaction));
    } finally {
      transaction.dispose();
    }
  } on Exception {
    return const Err(SyncInvalidTransactionFailure());
  }
}

/// Decodes the transaction a base64 PSBT describes, witnesses included only
/// when its inputs are finalized. The extraction checks the fee rate, so a
/// PSBT without its input amounts is refused.
Result<DecodedBitcoinTransaction, SyncFailure> decodeBitcoinPsbt(
  String psbtBase64,
) => _withPsbt(psbtBase64, (psbt) => Ok(_extract(psbt)));

/// The PSBT re-serialized by the parser: a check that [psbtBase64] is a PSBT.
Result<String, SyncFailure> canonicalBitcoinPsbt(String psbtBase64) =>
    _withPsbt(psbtBase64, (psbt) => Ok(psbt.serialize()));

/// Combines a signer's [signedBase64] with the [unsignedBase64] it was given
/// (a signer may drop the input data) and finalizes the result.
Result<DecodedBitcoinTransaction, SyncFailure> finalizeBitcoinPsbts({
  required String unsignedBase64,
  required String signedBase64,
}) => _withPsbt(
  unsignedBase64,
  (unsigned) => _withPsbt(signedBase64, (signed) {
    final bdk.Psbt combined;
    try {
      combined = unsigned.combine(other: signed);
    } on Exception {
      return const Err(SyncNotFinalizableFailure());
    }
    try {
      final finalized = combined.finalize();
      try {
        if (!finalized.couldFinalize) {
          return const Err(SyncNotFinalizableFailure());
        }
        return Ok(_extract(finalized.psbt));
      } finally {
        finalized.psbt.dispose();
      }
    } finally {
      combined.dispose();
    }
  }),
);

/// The address an output [script] pays to on [network], for display. A
/// non-standard script has none.
Result<String, SyncFailure> bitcoinScriptAddress(
  List<int> script,
  BitcoinNetwork network,
) {
  final native = _nativeNetwork(network);
  if (native == null) return const Err(SyncUnsupportedNetworkFailure());
  try {
    final nativeScript = bdk.Script(
      rawOutputScript: Uint8List.fromList(script),
    );
    try {
      final address = bdk.Address.fromScript(
        script: nativeScript,
        network: native,
      );
      try {
        return Ok(address.toString());
      } finally {
        address.dispose();
      }
    } finally {
      nativeScript.dispose();
    }
  } on Exception {
    return const Err(SyncInvalidAddressFailure());
  }
}

/// [address] in its canonical form when it is valid on [network]. Testnet
/// also accepts the historical Base58 encodings it shares with regtest.
Result<String, SyncFailure> parseBitcoinAddress(
  String address,
  BitcoinNetwork network,
) {
  final native = _nativeNetwork(network);
  if (native == null) return const Err(SyncUnsupportedNetworkFailure());
  try {
    final parsed = bdk.Address(address: address, network: native);
    try {
      return Ok(parsed.toString());
    } finally {
      parsed.dispose();
    }
  } on Exception {
    return const Err(SyncInvalidAddressFailure());
  }
}

bdk.Network? _nativeNetwork(BitcoinNetwork network) => switch (network) {
  BitcoinNetwork.mainnet => bdk.Network.bitcoin,
  BitcoinNetwork.testnet => bdk.Network.testnet,
  BitcoinNetwork.regtest => bdk.Network.regtest,
  BitcoinNetwork.signet => null,
};

Result<T, SyncFailure> _withPsbt<T>(
  String psbtBase64,
  Result<T, SyncFailure> Function(bdk.Psbt) read,
) {
  if (psbtBase64.isEmpty || psbtBase64.length > maxEncodedBitcoinPsbtLength) {
    return const Err(SyncInvalidTransactionFailure());
  }
  final bdk.Psbt psbt;
  try {
    psbt = bdk.Psbt(psbtBase64: psbtBase64);
  } on Exception {
    return const Err(SyncInvalidTransactionFailure());
  }
  try {
    return read(psbt);
  } on Exception {
    return const Err(SyncInvalidTransactionFailure());
  } finally {
    psbt.dispose();
  }
}

DecodedBitcoinTransaction _extract(bdk.Psbt psbt) {
  final transaction = psbt.extractTx();
  try {
    return _decode(transaction);
  } finally {
    transaction.dispose();
  }
}

DecodedBitcoinTransaction _decode(bdk.Transaction transaction) {
  final txid = transaction.computeTxid();
  final inputs = transaction.input();
  final outputs = transaction.output();
  try {
    return DecodedBitcoinTransaction(
      txid: txid.toString(),
      version: transaction.version(),
      locktime: transaction.lockTime(),
      size: transaction.totalSize(),
      vsize: transaction.vsize(),
      inputs: [
        for (final input in inputs)
          BitcoinTransactionInput(
            txid: input.previousOutput.txid.toString(),
            vout: input.previousOutput.vout,
            sequence: input.sequence,
            scriptSig: input.scriptSig.toBytes(),
          ),
      ],
      outputs: [
        for (final output in outputs)
          BitcoinTransactionOutput(
            valueSat: output.value.toSat(),
            script: output.scriptPubkey.toBytes(),
          ),
      ],
      bytes: transaction.serialize(),
    );
  } finally {
    txid.dispose();
    for (final input in inputs) {
      input.previousOutput.txid.dispose();
      input.scriptSig.dispose();
    }
    for (final output in outputs) {
      output.value.dispose();
      output.scriptPubkey.dispose();
    }
  }
}
