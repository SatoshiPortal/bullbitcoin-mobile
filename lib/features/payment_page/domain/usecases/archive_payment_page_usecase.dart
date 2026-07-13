import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_error.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/resolve_payment_page_identity_usecase.dart';

/// Signed soft-archive of the Donation Page (kind pinned to payment_page). The
/// server preserves the row (public URL keeps resolving to a deletion notice);
/// a later save revives it. A second archive returns DonationPageNotFound,
/// which is mapped to a benign already-archived outcome (null), not an error.
class ArchivePaymentPageUsecase {
  final ResolvePaymentPageIdentityUsecase _resolveIdentity;
  final BullnymFacade _bullnym;

  const ArchivePaymentPageUsecase({
    required this._resolveIdentity,
    required this._bullnym,
  });

  /// Returns the archived page, or null when it was already archived / absent.
  Future<PaymentPage?> execute() async {
    final identity = await _resolveIdentity.execute();
    final result = await _bullnym.archiveDonationPage(
      signer: identity.signer,
      nym: identity.nym,
      kind: bullnymDonationPageKindPaymentPage,
    );
    switch (result) {
      case Ok(:final value):
        return PaymentPage.fromBullnym(value);
      case Err(:final failure):
        final mapped = PaymentPageException.fromBullnym(failure);
        if (mapped.kind == PaymentPageErrorKind.notFound) {
          // Double archive / nothing to archive — benign.
          return null;
        }
        throw mapped;
    }
  }
}
