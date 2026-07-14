import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/pos/domain/pos_default_wallet_xprv_port.dart';
import 'package:bb_mobile/features/pos/domain/pos_error.dart';

class ResolvedPosIdentity {
  final String nym;
  final BullnymAuthSigner signer;

  const ResolvedPosIdentity({required this.nym, required this.signer});
}

/// Resolves the nym and the Bullnym auth signer that owns it, both derived from
/// THE default wallet xprv at point of use (charter H1: never stored, never
/// logged). The nym comes from the shared Lightning Address registration
/// (ROUTE-3W: one nym, wallet 101 for the LN address; this feature only reads
/// it - it does not create a second identity for the POS). A missing
/// registration surfaces as [PosException.noNym] so the cubit can route to the
/// DG-P6 first step.
class ResolvePosIdentityUsecase {
  static const _nymNotFoundCode = 'NymNotFound';

  final PosDefaultWalletXprvPort _defaultWalletXprv;
  final NostrIdentityFacade _nostrIdentity;
  final LightningAddressFacade _lightningAddress;

  const ResolvePosIdentityUsecase({
    required this._defaultWalletXprv,
    required this._nostrIdentity,
    required this._lightningAddress,
  });

  Future<ResolvedPosIdentity> execute() async {
    final xprvBase58 = await _deriveDefaultWalletXprv();
    final String npubHex;
    try {
      npubHex = _nostrIdentity.deriveBullnymServerAuthPublicKeyFromXprv(
        xprvBase58,
      );
    } catch (_) {
      throw const PosException.localPreparationFailed(
        code: 'BullnymIdentityDerivationFailed',
        retryable: false,
      );
    }

    final LightningAddressStatus status;
    try {
      status = await _lightningAddress.lookupRegistration(npubHex: npubHex);
    } on LightningAddressException catch (e) {
      if (e.code == _nymNotFoundCode) {
        throw const PosException.noNym();
      }
      throw posExceptionFromLightningAddress(e);
    } catch (_) {
      throw const PosException.unexpected();
    }

    final signer = BullnymAuthSigner(
      npubHex: npubHex,
      signHashHex: (messageHashHex) =>
          _nostrIdentity.signBullnymServerAuthHashFromXprv(
            xprvBase58: xprvBase58,
            messageHashHex: messageHashHex,
          ),
    );
    return ResolvedPosIdentity(nym: status.nym, signer: signer);
  }

  Future<String> _deriveDefaultWalletXprv() async {
    try {
      return await _defaultWalletXprv.deriveDefaultWalletXprv();
    } on PosException {
      rethrow;
    } catch (_) {
      throw const PosException.localPreparationFailed(
        code: 'DefaultWalletXprvFailed',
        retryable: true,
      );
    }
  }
}

/// Maps a Lightning Address lookup failure onto the pos family. The nym-absent
/// case is handled by the caller (→ noNym) before this is reached.
PosException posExceptionFromLightningAddress(LightningAddressException error) {
  return switch (error.kind) {
    LightningAddressErrorKind.invalidNym ||
    LightningAddressErrorKind.reservedNym ||
    LightningAddressErrorKind.invalidRegistrationInput =>
      PosException.invalidInput(code: error.code),
    LightningAddressErrorKind.localPreparationFailed
        when error.code == 'NoDefaultBitcoinWallet' =>
      const PosException.noDefaultBitcoinWallet(),
    LightningAddressErrorKind.localPreparationFailed =>
      PosException.localPreparationFailed(
        code: error.code,
        retryable: error.retryable,
      ),
    LightningAddressErrorKind.network => const PosException.network(),
    LightningAddressErrorKind.timeout => const PosException.timeout(),
    LightningAddressErrorKind.serverRejectedRequest =>
      error.retryable
          ? const PosException.server(retryable: true)
          : PosException.rejected(code: error.code),
    LightningAddressErrorKind.invalidServerResponse =>
      const PosException.invalidServerResponse(),
    LightningAddressErrorKind.signingFailed =>
      const PosException.signingFailed(),
    LightningAddressErrorKind.unexpected => const PosException.unexpected(),
  };
}
