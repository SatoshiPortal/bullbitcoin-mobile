import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration_liveness.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_wallet_owned_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/register_wallet_owned_lightning_address_usecase.dart';

final class EnsureLightningAddressRegistrationLiveUsecase {
  static const _nymNotFoundCode = 'NymNotFound';

  final LookupWalletOwnedLightningAddressRegistrationUsecase lookup;
  final RegisterWalletOwnedLightningAddressUsecase register;

  const EnsureLightningAddressRegistrationLiveUsecase({
    required this.lookup,
    required this.register,
  });

  Future<LightningAddressHealOutcome> execute() async {
    final LightningAddressStatus status;
    try {
      status = await lookup.execute();
    } on LightningAddressException catch (error) {
      return LightningAddressHealOutcome(
        liveness: error.code == _nymNotFoundCode
            ? LightningAddressRegistrationLiveness.needsReactivation
            : LightningAddressRegistrationLiveness.unreachable,
      );
    } catch (_) {
      return const LightningAddressHealOutcome(
        liveness: LightningAddressRegistrationLiveness.unreachable,
      );
    }

    if (status.active) {
      return LightningAddressHealOutcome(
        liveness: LightningAddressRegistrationLiveness.live,
        nym: status.nym,
        lightningAddress: status.lightningAddress,
      );
    }

    try {
      final registration = await register.execute(
        nym: status.nym,
        publishBackupSnapshot: false,
      );
      return LightningAddressHealOutcome(
        liveness: LightningAddressRegistrationLiveness.reregistered,
        nym: registration.registration.nym,
        lightningAddress: registration.registration.lightningAddress,
      );
    } catch (error, stack) {
      log.warning(
        'Lightning Address silent re-registration failed',
        error: error.runtimeType,
        trace: stack,
      );
      return LightningAddressHealOutcome(
        liveness: LightningAddressRegistrationLiveness.needsReactivation,
        nym: status.nym,
      );
    }
  }
}
