/// Abstract transaction — shared structure across Bitcoin, Liquid,
/// and (in the future) Ark.
///
/// Every UTXO-based transaction has a txid, version, virtual size,
/// locktime, a list of inputs, and a list of outputs.
abstract class Transaction {
  const Transaction();

  String get txid;
  int get version;
  int get vsize;
  int get locktime;
  List<TxInput> get inputs;
  List<TxOutput> get outputs;

  /// Total value of all outputs in satoshis.
  int get totalOutputsSat =>
      outputs.fold<int>(0, (sum, output) => sum + output.valueSat);
}

/// Abstract transaction input — references a previous transaction output.
abstract class TxInput {
  const TxInput();

  /// The txid of the transaction containing the output being spent.
  String get previousTxId;

  /// The vout index of the output being spent in the previous transaction.
  int get previousVout;

  /// The value in satoshis of this input.
  /// May be null if the value has not been resolved yet
  /// (e.g. for an external transaction before fetching parent txs).
  int? get valueSat;
}

/// Abstract transaction output.
abstract class TxOutput {
  const TxOutput();

  /// The value in satoshis.
  int get valueSat;

  /// The output index within the transaction.
  int get index;

  /// The address this output pays to, if decodable.
  String? get address;

  /// The raw scriptPubKey as a hex string.
  String get scriptPubKeyHex;
}
