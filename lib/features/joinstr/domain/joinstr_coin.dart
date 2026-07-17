/// A spendable wallet UTXO the user can pick as the input for a coinjoin,
/// mirroring the "Select a UTXO" list in joinstr-kmp and floresta_wallet.
class JoinstrCoin {
  final String txid;
  final int vout;
  final int valueSat;

  const JoinstrCoin({
    required this.txid,
    required this.vout,
    required this.valueSat,
  });

  /// Stable identity used to pass the chosen coin down to the bindings and to
  /// exclude coins already committed to another in-flight pool.
  String get outpoint => '$txid:$vout';
}
