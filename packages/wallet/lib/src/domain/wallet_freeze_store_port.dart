import 'package:primitives/primitives.dart' show Outpoint;

/// Persistence of user-frozen outputs, independent of the host database.
///
/// Attribution uses the wallet origin. Exclusion and unfreezing use the
/// globally unique outpoint, including freezes imported without attribution.
abstract interface class WalletFreezeStorePort {
  Future<void> freezeOutpoints({
    required String walletId,
    required List<Outpoint> outpoints,
  });

  Future<void> unfreezeOutpoints({
    required String walletId,
    required List<Outpoint> outpoints,
  });

  Future<List<Outpoint>> getFrozenOutpoints({required String walletId});

  Future<List<({String walletId, String txId, int vout})>> getAllFrozen();
}
