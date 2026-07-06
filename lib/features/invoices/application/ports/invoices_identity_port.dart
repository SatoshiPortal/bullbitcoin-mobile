import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart'
    show BullnymAuthSigner;

/// Resolves the Get Paid signing identity for invoices. Unlinked v1 needs ONLY
/// the npub signer — no nym, no Lightning Address registration. The signer
/// derives from the DEFAULT wallet xprv at point of use (charter H1: never
/// stored, never logged) and is the SAME npub as the Donation Page / POS.
///
/// Throws `InvoicesException.signingFailed` (or a typed identity-unavailable
/// error) when there is no default wallet to derive the identity from.
abstract interface class InvoicesIdentityPort {
  Future<BullnymAuthSigner> getSigningHandle();
}
