import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/remote_keychain_recovery/domain/recovered_products_heal_outcome.dart';

final class HealRecoveredProductsUsecase {
  static const _lightningAddressReservationId = 'lightning_address_wallet_seed';

  final LightningAddressFacade _lightningAddress;

  const HealRecoveredProductsUsecase(this._lightningAddress);

  Future<RecoveredProductsHealOutcome> execute(
    Set<String> reactivationReservationIds,
  ) async {
    LightningAddressHealOutcome? lightningAddress;
    if (reactivationReservationIds.contains(_lightningAddressReservationId)) {
      lightningAddress = await _healLightningAddress();
    }
    return RecoveredProductsHealOutcome(lightningAddress: lightningAddress);
  }

  Future<LightningAddressHealOutcome> _healLightningAddress() async {
    try {
      return await _lightningAddress.ensureRegistrationLive();
    } catch (error, stack) {
      log.warning(
        'Lightning Address recovery heal failed',
        error: error.runtimeType,
        trace: stack,
      );
      return const LightningAddressHealOutcome(
        liveness: LightningAddressRegistrationLiveness.unreachable,
      );
    }
  }
}
