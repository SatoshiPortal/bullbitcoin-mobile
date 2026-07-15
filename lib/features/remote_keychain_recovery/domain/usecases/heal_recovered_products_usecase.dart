import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/payment_page/public/payment_page_facade.dart';
import 'package:bb_mobile/features/pos/public/pos_facade.dart';
import 'package:bb_mobile/features/remote_keychain_recovery/domain/recovered_products_heal_outcome.dart';

/// Runs the DG-3 auto-heal for the products a restore flagged for reactivation.
///
/// Lightning Address delegates to its facade's conditional liveness check
/// (silent re-register if lapsed-but-known; never an unconditional prompt).
/// Payment Page and POS delegate to their read-only liveness checks (GET only;
/// live/archived products are silent, missing products surface
/// needsReactivation, and unreachable servers degrade loudly). Each product is
/// healed independently. Unknown failures never throw; they degrade to the
/// per-product `unreachable`.
class HealRecoveredProductsUsecase {
  static const _lightningAddressReservationId = 'lightning_address_wallet_seed';
  static const _paymentPageReservationId = 'payment_page_wallet_seed';
  static const _posReservationId = 'pos_wallet_seed';

  final LightningAddressFacade _lightningAddress;
  final PaymentPageFacade _paymentPage;
  final PosFacade _pos;

  const HealRecoveredProductsUsecase(
    this._lightningAddress,
    this._paymentPage,
    this._pos,
  );

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

    PosHealOutcome? posOutcome;
    if (reactivationReservationIds.contains(_posReservationId)) {
      posOutcome = await _healPos();
    }

    return RecoveredProductsHealOutcome(
      lightningAddress: lightningAddressOutcome,
      paymentPage: paymentPageOutcome,
      pos: posOutcome,
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

  Future<PosHealOutcome> _healPos() async {
    try {
      return await _pos.ensurePosLive();
    } catch (e, stack) {
      log.warning(
        'AUTOHEAL: point of sale heal failed',
        error: e,
        trace: stack,
      );
      return const PosHealOutcome(liveness: PosLiveness.unreachable);
    }
  }
}
