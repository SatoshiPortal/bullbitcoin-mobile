export 'package:bb_mobile/features/get_paid_settings/public/get_paid_settings_facade.dart'
    show GetPaidWalletBehavior;

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/get_paid_settings/public/get_paid_settings_facade.dart';

sealed class LightningAddressWalletBehaviorRead {
  const LightningAddressWalletBehaviorRead();
}

final class LightningAddressWalletBehaviorFound
    extends LightningAddressWalletBehaviorRead {
  final GetPaidWalletBehavior behavior;

  const LightningAddressWalletBehaviorFound(this.behavior);
}

final class LightningAddressWalletBehaviorAbsent
    extends LightningAddressWalletBehaviorRead {
  const LightningAddressWalletBehaviorAbsent();
}

final class LightningAddressWalletBehaviorUnavailable
    extends LightningAddressWalletBehaviorRead {
  const LightningAddressWalletBehaviorUnavailable();
}

/// Lightning Address's own wrapper over the Get Paid settings boundary: read
/// the reserved wallet (101)'s display/sweep behavior.
///
/// A confirmed missing wallet and an unavailable read remain distinct so the
/// screen never hides a settings outage as though wallet 101 did not exist.
class GetLightningAddressWalletBehaviorUsecase {
  final GetPaidSettingsFacade _getPaidSettings;

  const GetLightningAddressWalletBehaviorUsecase({
    required this._getPaidSettings,
  });

  Future<LightningAddressWalletBehaviorRead> execute() async {
    return switch (await _getPaidSettings.walletBehaviors(
      only: GetPaidWalletProduct.lightningAddress,
    )) {
      Err() => const LightningAddressWalletBehaviorUnavailable(),
      Ok(value: []) => const LightningAddressWalletBehaviorAbsent(),
      Ok(:final value) => LightningAddressWalletBehaviorFound(value.single),
    };
  }
}
