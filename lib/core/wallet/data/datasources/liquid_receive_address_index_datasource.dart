import 'package:shared_preferences/shared_preferences.dart';

/// Persists, per Liquid wallet, the highest receive-address index this app
/// has ever handed out to the UI — independent of LWK's own sync state.
///
/// LWK's "last unused address" is derived purely from what the wallet has
/// synced as used; two receive requests issued before an intervening sync
/// would otherwise return the identical address (there's no LWK-side
/// reservation mechanism, unlike BDK's persisted, sync-independent
/// reveal-index — see `BdkWalletDatasource.getNewAddress` /
/// `BdkFacade.saveWallet`). This datasource is that missing reservation for
/// Liquid, so the same class of address reuse can't happen there either.
class LiquidReceiveAddressIndexDatasource {
  static String _key(String walletId) =>
      'liquid_last_receive_address_index_$walletId';

  // Per-wallet async mutex: each call for a given walletId waits for the
  // previous one (for that same wallet) to finish before reading, so a
  // concurrent reservation race can't have two callers read the same
  // "current" value before either writes back. Different wallets never
  // block each other.
  final Map<String, Future<void>> _locks = {};

  /// The persisted index, or null if nothing has ever been reserved for
  /// this wallet yet.
  Future<int?> read(String walletId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(walletId));
  }

  /// Atomically reserves and persists a new "last issued" index for
  /// [walletId]: `max(persisted, atLeast) + 1`. [atLeast] should be LWK's
  /// own sync-derived next-unused index, so a wallet restored on a new
  /// device (where the local persisted counter starts at 0) still advances
  /// correctly. Concurrent calls for the same wallet are serialized, so
  /// each one is guaranteed a distinct reserved index.
  Future<int> reserveNext(String walletId, {required int atLeast}) {
    final previous = _locks[walletId] ?? Future.value();
    final chained = previous.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_key(walletId)) ?? 0;
      final next = (current > atLeast ? current : atLeast) + 1;
      await prefs.setInt(_key(walletId), next);
      return next;
    });
    // Release the lock once this reservation settles, whatever the outcome,
    // so a failure here can't deadlock every later call for this wallet.
    _locks[walletId] = chained.then((_) {}, onError: (_) {});
    return chained;
  }

  /// Self-heals the persisted index up to [atLeast] without reserving a new
  /// one — used when the address actually returned to the UI (after any
  /// system-label skip-forward) ended up higher than what's currently
  /// persisted, so the next reservation still starts from the right place.
  Future<void> ensureAtLeast(String walletId, int atLeast) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_key(walletId)) ?? 0;
    if (atLeast > current) {
      await prefs.setInt(_key(walletId), atLeast);
    }
  }
}
