import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_error.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_liveness.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/find_payment_page_usecase.dart';

/// DG-3 recovery heal for the Donation Page (§3.12). READ-ONLY: it looks the
/// registration up (shared LA registration), GETs the page (kind-scoped), and
/// classifies. It NEVER issues a PUT (a save would clear `archived_at` — a
/// resurrect/clobber hazard) and NEVER re-registers. The recovery cubit is the
/// sole backup publisher, so this path publishes nothing (T-NOCLOBBER).
///
/// - page present & not archived -> [live] (silent);
/// - page archived               -> [archivedByUser] (respect the archive);
/// - registration live, page absent (or no nym) -> [needsReactivation]
///   (one-tap recreate — content is unknowable client-side);
/// - network/timeout/server      -> [unreachable] (liveness UNKNOWN; loud).
class EnsurePaymentPageLiveUsecase {
  static const _nymNotFoundCode = 'NymNotFound';

  final LightningAddressFacade _lightningAddress;
  final FindPaymentPageUsecase _findPage;

  const EnsurePaymentPageLiveUsecase({
    required this._lightningAddress,
    required this._findPage,
  });

  Future<PaymentPageHealOutcome> execute() async {
    final String nym;
    try {
      final status = await _lightningAddress.lookupWalletOwnedRegistration();
      nym = status.nym;
    } on LightningAddressException catch (e) {
      if (e.code == _nymNotFoundCode) {
        // No registration for this seed — the page cannot exist; route to
        // re-activation rather than reporting a fake-live page.
        return const PaymentPageHealOutcome(
          liveness: PaymentPageLiveness.needsReactivation,
        );
      }
      return const PaymentPageHealOutcome(
        liveness: PaymentPageLiveness.unreachable,
      );
    } catch (_) {
      return const PaymentPageHealOutcome(
        liveness: PaymentPageLiveness.unreachable,
      );
    }

    try {
      final page = await _findPage.execute(nym: nym);
      if (page == null) {
        return const PaymentPageHealOutcome(
          liveness: PaymentPageLiveness.needsReactivation,
        );
      }
      return PaymentPageHealOutcome(
        liveness: page.isArchived
            ? PaymentPageLiveness.archivedByUser
            : PaymentPageLiveness.live,
      );
    } on PaymentPageException {
      // Liveness UNKNOWN — never fake-live on a failure.
      return const PaymentPageHealOutcome(
        liveness: PaymentPageLiveness.unreachable,
      );
    } catch (_) {
      return const PaymentPageHealOutcome(
        liveness: PaymentPageLiveness.unreachable,
      );
    }
  }
}
