import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Reads the txid of a payin before it is broadcast.
class ReadSellPayinTxidUsecase {
  const ReadSellPayinTxidUsecase();

  @useResult
  Future<Result<String, SellFailure>> fromPsbt(String unsignedPsbt) async {
    try {
      final tx = await BitcoinTx.fromPsbt(unsignedPsbt);
      return Ok(tx.txid);
    } catch (e, st) {
      log.severe(
        message: 'Failed to read the txid of the Bitcoin sell payin',
        error: e,
        trace: st,
      );
      return Err(SellUnexpectedFailure('$e'));
    }
  }

  @useResult
  Future<Result<String, SellFailure>> fromPset(String signedPset) async {
    try {
      final tx = await _LiquidTx.fromPset(signedPset);
      return Ok(tx.txid);
    } catch (e, st) {
      log.severe(
        message: 'Failed to read the txid of the Liquid sell payin',
        error: e,
        trace: st,
      );
      return Err(SellUnexpectedFailure('$e'));
    }
  }
}

class _LiquidTx {
  final String txid;
  final int version;
  final BigInt vsize;
  final BigInt weight;
  final int locktime;
  final BigInt fee;
  final List<_LiquidTxVin> vin;
  final List<_LiquidTxVout> vout;

  List<_LiquidTxVin> get inputs => vin;
  List<_LiquidTxVout> get outputs => vout;

  const _LiquidTx({
    required this.txid,
    required this.version,
    required this.vsize,
    required this.weight,
    required this.locktime,
    required this.fee,
    required this.vin,
    required this.vout,
  });

  static Future<_LiquidTx> fromBytes(List<int> bytes) async {
    final tx = lwk.LiquidTransaction.fromBytes(txBytes: bytes);
    final txid = tx.txid();
    final version = tx.version();
    final vsize = tx.vsize();
    final weight = tx.weight();
    final fee = tx.fee();
    final locktime = tx.lockTime();
    final inputs = tx.getInputs();
    final outputs = tx.getOutputs();

    final vout = <_LiquidTxVout>[];
    for (var i = 0; i < outputs.length; i++) {
      final output = outputs[i];
      vout.add(_mapOutput(output, i));
    }

    return _LiquidTx(
      txid: txid,
      version: version,
      vsize: vsize,
      weight: weight,
      locktime: locktime,
      fee: fee,
      vin: inputs.map(_mapInput).toList(),
      vout: vout,
    );
  }

  static Future<_LiquidTx> fromPset(String psetString) async {
    final pset = lwk.PartiallySignedElementsTransaction.fromString(
      psetString: psetString,
    );
    final txBytes = pset.extractTx().toBytes();
    return fromBytes(txBytes);
  }

  static _LiquidTxVin _mapInput(lwk.TxInput input) {
    return _LiquidTxVin(
      txid: input.txid,
      vout: input.vout,
      sequence: input.sequence,
      scriptSig: input.scriptSig,
      witness: input.witness,
      isPegin: input.isPegin,
    );
  }

  static _LiquidTxVout _mapOutput(lwk.TxOutput output, int index) {
    return _LiquidTxVout(
      value: output.value,
      n: index,
      asset: output.asset,
      scriptPubKey: output.scriptPubkey,
      nonce: output.nonce,
    );
  }
}

class _LiquidTxVin {
  final String txid;
  final int vout;
  final int sequence;
  final String scriptSig;
  final List<String> witness;
  final bool isPegin;

  const _LiquidTxVin({
    required this.txid,
    required this.vout,
    required this.sequence,
    required this.scriptSig,
    required this.witness,
    required this.isPegin,
  });
}

class _LiquidTxVout {
  final BigInt? value;
  final int n;
  final String? asset;
  final String scriptPubKey;
  final String? nonce;

  const _LiquidTxVout({
    required this.value,
    required this.n,
    required this.asset,
    required this.scriptPubKey,
    required this.nonce,
  });
}
