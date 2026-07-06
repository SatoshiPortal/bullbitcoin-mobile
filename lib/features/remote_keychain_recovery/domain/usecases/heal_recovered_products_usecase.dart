import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/payment_page/public/payment_page_facade.dart';
import 'package:bb_mobile/features/remote_keychain_recovery/domain/recovered_products_heal_outcome.dart';

/// Runs the DG-3 auto-heal for the products a restore flagged for reactivation.
///
/// Lightning Address delegates to its facade's conditional liveness check
/// (silent re-register if lapsed-but-known; never an unconditional prompt).
/// Payment Page delegates to its read-only liveness check (GET only; live and
/// archived pages are silent, a missing page surfaces needsReactivation, and an
/// unreachable server degrades loudly). Each product is healed independently.
/// Unknown failures never throw; they degrade to the per-product `unreachable`.
class HealRecoveredProductsUsecase {
  static const _lightningAddressReservationId = 'lightning_address_wallet_seed';
  static const _paymentPageReservationId = 'payment_page_wallet_seed';

  final LightningAddressFacade _lightningAddress;
  final PaymentPageFacade _paymentPage;

  const HealRecoveredProductsUsecase(this._lightningAddress, this._paymentPage);

  Future<RecoveredProductsHealOutcome> execute(
    Set<String> reactivationReservationIds,
  ) async {
    LightningAddressHealOutcome? lightningAddressOutcome;
    if (reactivationReservationIds.contains(_lightningAddressReservationId)) {
      lightningAddressOutcome = await _healLightningAddress();
    }

    PaymentPageHealOutcome? paymentPageOutcome;
    if (reactivationReservationIds.contains(_paymentPageReservationId)) {
      paymentPageOutcome = await _healPaymentPage();
    }

    return RecoveredProductsHealOutcome(
      lightningAddress: lightningAddressOutcome,
      paymentPage: paymentPageOutcome,
    );
  }

  Future<LightningAddressHealOutcome> _healLightningAddress() async {
    try {
      return await _lightningAddress.ensureRegistrationLive();
    } catch (e, stack) {
      log.warning(
        'AUTOHEAL: lightning address heal failed',
        error: e,
        trace: stack,
      );
      return const LightningAddressHealOutcome(
        liveness: LightningAddressRegistrationLiveness.unreachable,
      );
    }
  }

  Future<PaymentPageHealOutcome> _healPaymentPage() async {
    try {
      return await _paymentPage.ensurePageLive();
    } catch (e, stack) {
      log.warning('AUTOHEAL: payment page heal failed', error: e, trace: stack);
      return const PaymentPageHealOutcome(
        liveness: PaymentPageLiveness.unreachable,
      );
    }
  }
}
