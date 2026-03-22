/// In-memory store for the DLC wallet authentication token and derived
/// funding public key. This is populated after a successful wallet
/// registration and cleared on sign-out.
///
/// Held as a lazy singleton in [DlcLocator] so that [DlcApiDatasource]
/// and [DlcPlaceOrderCubit] always read the latest values.
class DlcWalletTokenStore {
  String? _walletToken;
  String? _fundingPubkeyHex;
  String? _walletId;

  String? get walletToken => _walletToken;
  String? get fundingPubkeyHex => _fundingPubkeyHex;
  String? get walletId => _walletId;

  bool get isRegistered => _walletToken != null;

  void setRegistration({
    required String walletToken,
    required String fundingPubkeyHex,
    required String walletId,
  }) {
    _walletToken = walletToken;
    _fundingPubkeyHex = fundingPubkeyHex;
    _walletId = walletId;
  }

  void clear() {
    _walletToken = null;
    _fundingPubkeyHex = null;
    _walletId = null;
  }
}
