import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_default_wallet_xprv_port.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_error.dart';

class ResolvedPaymentPageIdentity {
  final String nym;
  final BullnymAuthSigner signer;

  const ResolvedPaymentPageIdentity({required this.nym, required this.signer});
}

/// Resolves the nym and the Bullnym auth signer that owns it, both derived from
/// THE default wallet xprv at point of use (charter H1: never stored, never
/// logged). The nym comes from the shared Lightning Address registration
/// (ROUTE-3W: one nym, wallet 101 for the LN address; this feature only reads
/// it). A missing registration surfaces as [PaymentPageException.noNym] so the
/// cubit can route to the DG-6 first step.
class ResolvePaymentPageIdentityUsecase {
  static const _nymNotFoundCode = 'NymNotFound';

  final PaymentPageDefaultWalletXprvPort _defaultWalletXprv;
  final NostrIdentityFacade _nostrIdentity;
  final LightningAddressFacade _lightningAddress;

  const ResolvePaymentPageIdentityUsecase({
    required this._defaultWalletXprv,
    required this._nostrIdentity,
    required this._lightningAddress,
  });

  Future<ResolvedPaymentPageIdentity> execute() async {
    final xprvBase58 = await _deriveDefaultWalletXprv();
    final String npubHex;
    try {
      npubHex = _nostrIdentity.deriveBullnymServerAuthPublicKeyFromXprv(
        xprvBase58,
      );
    } catch (_) {
      throw const PaymentPageException.localPreparationFailed(
        code: 'BullnymIdentityDerivationFailed',
        retryable: false,
      );
    }

    final LightningAddressStatus status;
    try {
      status = await _lightningAddress.lookupRegistration(npubHex: npubHex);
    } on LightningAddressException catch (e) {
      if (e.code == _nymNotFoundCode) {
        throw const PaymentPageException.noNym();
      }
      throw paymentPageExceptionFromLightningAddress(e);
    } catch (_) {
      throw const PaymentPageException.unexpected();
    }

    final signer = BullnymAuthSigner(
      npubHex: npubHex,
      signHashHex: (messageHashHex) =>
          _nostrIdentity.signBullnymServerAuthHashFromXprv(
            xprvBase58: xprvBase58,
            messageHashHex: messageHashHex,
          ),
    );
    return ResolvedPaymentPageIdentity(nym: status.nym, signer: signer);
  }

  Future<String> _deriveDefaultWalletXprv() async {
    try {
      return await _defaultWalletXprv.deriveDefaultWalletXprv();
    } on PaymentPageException {
      rethrow;
    } catch (_) {
      throw const PaymentPageException.localPreparationFailed(
        code: 'DefaultWalletXprvFailed',
        retryable: true,
      );
    }
  }
}

/// Maps a Lightning Address lookup failure onto the payment_page family. The
/// nym-absent case is handled by the caller (→ noNym) before this is reached.
PaymentPageException paymentPageExceptionFromLightningAddress(
  LightningAddressException error,
) {
  return switch (error.kind) {
    LightningAddressErrorKind.invalidNym ||
    LightningAddressErrorKind.invalidRegistrationInput =>
      PaymentPageException.invalidInput(code: error.code),
    LightningAddressErrorKind.localPreparationFailed
        when error.code == 'NoDefaultBitcoinWallet' =>
      const PaymentPageException.noDefaultBitcoinWallet(),
    LightningAddressErrorKind.localPreparationFailed =>
      PaymentPageException.localPreparationFailed(
        code: error.code,
        retryable: error.retryable,
      ),
    LightningAddressErrorKind.network => const PaymentPageException.network(),
    LightningAddressErrorKind.timeout => const PaymentPageException.timeout(),
    LightningAddressErrorKind.serverRejectedRequest =>
      error.retryable
          ? const PaymentPageException.server(retryable: true)
          : PaymentPageException.rejected(code: error.code),
    LightningAddressErrorKind.invalidServerResponse =>
      const PaymentPageException.invalidServerResponse(),
    LightningAddressErrorKind.signingFailed =>
      const PaymentPageException.signingFailed(),
    LightningAddressErrorKind.unexpected =>
      const PaymentPageException.unexpected(),
  };
}
