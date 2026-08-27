/// The labels feature's view of the freeze store, so BIP329 export/import can
/// read and write freeze state without depending on `core/wallet` internals.
///
/// `walletId` is the wallet origin (`wallet.id => origin`). A `null` walletId on
/// [freeze] means the imported record carried no parseable origin — it is
/// stored unattributed (inert until a wallet owns the coin).
abstract class WalletFreezePort {
  Future<List<({String walletId, String txId, int vout})>> getAllFrozen();

  Future<void> freeze(
    List<({String? walletId, String txId, int vout})> outputs,
  );

  /// Returns the outpoints currently owned by [walletId]. Imported freezes
  /// are validated against this set so a labels file can never freeze coins
  /// the wallet does not hold (issue #2605).
  Future<List<({String txId, int vout})>> getOwnedOutpoints({
    required String walletId,
  });
}
