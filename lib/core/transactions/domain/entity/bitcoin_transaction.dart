import 'package:bb_mobile/core/transactions/domain/entity/transaction.dart';

/// Concrete Bitcoin transaction implementing the abstract [Transaction].
class BitcoinTransaction extends Transaction {
  @override
  final String txid;
  @override
  final int version;
  @override
  final int vsize;
  @override
  final int locktime;
  @override
  final List<BitcoinTxInput> inputs;
  @override
  final List<BitcoinTxOutput> outputs;

  /// Raw transaction size in bytes.
  final int size;

  const BitcoinTransaction({
    required this.txid,
    required this.version,
    required this.size,
    required this.vsize,
    required this.locktime,
    required this.inputs,
    required this.outputs,
  });
}

/// Concrete Bitcoin transaction input implementing [TxInput].
class BitcoinTxInput extends TxInput {
  @override
  final String previousTxId;
  @override
  final int previousVout;
  @override
  final int? valueSat;

  /// The input's sequence number.
  final int sequence;

  /// The scriptSig bytes, if available.
  final List<int>? scriptSigBytes;

  const BitcoinTxInput({
    required this.previousTxId,
    required this.previousVout,
    this.valueSat,
    required this.sequence,
    this.scriptSigBytes,
  });
}

/// Concrete Bitcoin transaction output implementing [TxOutput].
class BitcoinTxOutput extends TxOutput {
  @override
  final int valueSat;
  @override
  final int index;
  @override
  final String? address;
  @override
  final String scriptPubKeyHex;

  /// The raw scriptPubKey bytes.
  final List<int> scriptPubKeyBytes;

  const BitcoinTxOutput({
    required this.valueSat,
    required this.index,
    this.address,
    required this.scriptPubKeyHex,
    required this.scriptPubKeyBytes,
  });
}
