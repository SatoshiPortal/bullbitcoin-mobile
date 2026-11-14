import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';

import '../../domain/decoded_transactions.dart';
import '../../domain/sync_failure.dart';

/// Elements keeps Bitcoin's 4,000,000 weight-unit limit, proofs included, so a
/// valid transaction never serializes to more bytes than this.
const maxLiquidTransactionBytes = 4000000;

/// Bounds the encoded PSET before the native parser sees it.
const maxEncodedLiquidPsetLength = 16 * 1024 * 1024;

/// Decodes consensus bytes. Library function: no wallet is opened.
Result<DecodedLiquidTransaction, SyncFailure> decodeLiquidTransaction(
  List<int> bytes,
) {
  if (bytes.isEmpty || bytes.length > maxLiquidTransactionBytes) {
    return const Err(SyncInvalidTransactionFailure());
  }
  try {
    return Ok(_decode(lwk.LiquidTransaction.fromBytes(txBytes: bytes)));
  } on Exception {
    return const Err(SyncInvalidTransactionFailure());
  }
}

/// Decodes the transaction a base64 PSET describes. Values it keeps
/// confidential stay unknown.
Result<DecodedLiquidTransaction, SyncFailure> decodeLiquidPset(String pset) {
  if (pset.isEmpty || pset.length > maxEncodedLiquidPsetLength) {
    return const Err(SyncInvalidTransactionFailure());
  }
  try {
    final parsed = lwk.PartiallySignedElementsTransaction.fromString(
      psetString: pset,
    );
    return Ok(_decode(parsed.extractTx()));
  } on Exception {
    return const Err(SyncInvalidTransactionFailure());
  }
}

/// A PSET's discounted virtual size and its explicit fee, in the policy
/// asset, as fee estimation counts them.
Future<Result<({int discountedVsize, int feeSat}), SyncFailure>> liquidPsetFees(
  String pset,
) async {
  if (pset.isEmpty || pset.length > maxEncodedLiquidPsetLength) {
    return const Err(SyncInvalidTransactionFailure());
  }
  try {
    final decoded = await lwk.getSizeAndAbsoluteFees(pset: pset);
    final fee = decoded.absoluteFees.firstOrNull;
    if (fee == null) return const Err(SyncInvalidTransactionFailure());
    return Ok((
      discountedVsize: decoded.discountedVsize.toInt(),
      feeSat: fee.value.toInt(),
    ));
  } on Exception {
    return const Err(SyncInvalidTransactionFailure());
  }
}

/// The Liquid network [address] belongs to.
Future<Result<LiquidNetwork, SyncFailure>> liquidAddressNetwork(
  String address,
) async {
  try {
    return Ok(switch (await lwk.Address.validate(addressString: address)) {
      lwk.LiquidNetwork.mainnet => LiquidNetwork.mainnet,
      lwk.LiquidNetwork.testnet => LiquidNetwork.testnet,
      lwk.LiquidNetwork.regtest => LiquidNetwork.regtest,
    });
  } on Exception {
    return const Err(SyncInvalidAddressFailure());
  }
}

DecodedLiquidTransaction _decode(lwk.LiquidTransaction transaction) =>
    DecodedLiquidTransaction(
      txid: transaction.txid(),
      version: transaction.version(),
      locktime: transaction.lockTime(),
      vsize: transaction.vsize(),
      weight: transaction.weight(),
      feeSat: transaction.fee(),
      inputs: [
        for (final input in transaction.getInputs())
          LiquidTransactionInput(
            txid: input.txid,
            vout: input.vout,
            sequence: input.sequence,
            isPegin: input.isPegin,
          ),
      ],
      outputs: [
        for (final output in transaction.getOutputs())
          LiquidTransactionOutput(
            scriptHex: output.scriptPubkey,
            asset: output.asset,
            valueSat: output.value,
          ),
      ],
    );
