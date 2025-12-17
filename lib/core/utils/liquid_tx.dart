import 'package:lwk/lwk.dart' as lwk;

class LiquidTx {
  final String txid;
  final int version;
  final BigInt vsize;
  final BigInt weight;
  final int locktime;
  final BigInt fee;
  final List<LiquidTxVin> vin;
  final List<LiquidTxVout> vout;

  List<LiquidTxVin> get inputs => vin;
  List<LiquidTxVout> get outputs => vout;

  const LiquidTx({
    required this.txid,
    required this.version,
    required this.vsize,
    required this.weight,
    required this.locktime,
    required this.fee,
    required this.vin,
    required this.vout,
  });

  static Future<LiquidTx> fromBytes(List<int> bytes) async {
    final tx = lwk.LiquidTransaction.fromBytes(txBytes: bytes);
    final txid = tx.txid();
    final version = tx.version();
    final vsize = tx.vsize();
    final weight = tx.weight();
    final fee = tx.fee();
    final locktime = tx.lockTime();
    final inputs = tx.getInputs();
    final outputs = tx.getOutputs();

    final vout = <LiquidTxVout>[];
    for (var i = 0; i < outputs.length; i++) {
      final output = outputs[i];
      vout.add(_mapOutput(output, i));
    }

    return LiquidTx(
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

  static Future<LiquidTx> fromPset(String psetString) async {
    final pset = lwk.PartiallySignedElementsTransaction.fromString(
      psetString: psetString,
    );
    final txBytes = pset.extractTx().toBytes();
    return fromBytes(txBytes);
  }

  static LiquidTxVin _mapInput(lwk.TxInput input) {
    return LiquidTxVin(
      txid: input.txid,
      vout: input.vout,
      sequence: input.sequence,
      scriptSig: input.scriptSig,
      witness: input.witness,
      isPegin: input.isPegin,
    );
  }

  static LiquidTxVout _mapOutput(lwk.TxOutput output, int index) {
    return LiquidTxVout(
      value: output.value,
      n: index,
      asset: output.asset,
      scriptPubKey: output.scriptPubkey,
      nonce: output.nonce,
    );
  }
}

class LiquidTxVin {
  final String txid;
  final int vout;
  final int sequence;
  final String scriptSig;
  final List<String> witness;
  final bool isPegin;

  const LiquidTxVin({
    required this.txid,
    required this.vout,
    required this.sequence,
    required this.scriptSig,
    required this.witness,
    required this.isPegin,
  });
}

class LiquidTxVout {
  final BigInt? value;
  final int n;
  final String? asset;
  final String scriptPubKey;
  final String? nonce;

  const LiquidTxVout({
    required this.value,
    required this.n,
    required this.asset,
    required this.scriptPubKey,
    required this.nonce,
  });
}
