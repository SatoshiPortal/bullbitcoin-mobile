import 'package:bb_mobile/features/nostr_identity/domain/derive_nostr_identity_handle_usecase.dart';

class NostrIdentityFacade {
  final DeriveNostrIdentityHandleUsecase _deriveHandle;

  const NostrIdentityFacade({required this._deriveHandle});

  String deriveWalletManifestPublicKeyFromXprv(String xprvBase58) {
    final handle = _deriveHandle.execute(
      xprvBase58: xprvBase58,
      role: NostrIdentityRole.walletManifest,
    );
    return handle.publicKeyHex;
  }

  String deriveBullnymServerAuthPublicKeyFromXprv(String xprvBase58) {
    final handle = _deriveHandle.execute(
      xprvBase58: xprvBase58,
      role: NostrIdentityRole.bullnymServerAuth,
    );
    return handle.publicKeyHex;
  }

  String signWalletManifestHashFromXprv({
    required String xprvBase58,
    required String messageHashHex,
  }) {
    final handle = _deriveHandle.execute(
      xprvBase58: xprvBase58,
      role: NostrIdentityRole.walletManifest,
    );
    return handle.signHashHex(messageHashHex);
  }

  String signBullnymServerAuthHashFromXprv({
    required String xprvBase58,
    required String messageHashHex,
  }) {
    final handle = _deriveHandle.execute(
      xprvBase58: xprvBase58,
      role: NostrIdentityRole.bullnymServerAuth,
    );
    return handle.signHashHex(messageHashHex);
  }
}
