import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart'
    show BullnymAuthSigner;
import 'package:bb_mobile/features/invoices/domain/invoices_failure.dart';
import 'package:meta/meta.dart';

/// Resolves the Get Paid signing identity for invoices. Unlinked v1 needs ONLY
/// the npub signer — no nym, no Lightning Address registration. The signer
/// derives from the DEFAULT wallet xprv at point of use (charter H1: never
/// stored, never logged) and is the SAME npub as the Donation Page / POS.
///
/// Returns a typed failure when there is no default wallet or the ephemeral
/// signing identity cannot be derived.
abstract interface class InvoicesIdentityPort {
  @useResult
  Future<Result<BullnymAuthSigner, InvoicesFailure>> getSigningHandle();
}
