/// The native coin-selection boundary needs only an outpoint.
abstract interface class WalletCoinPort {
  String get txId;
  int get vout;
}
