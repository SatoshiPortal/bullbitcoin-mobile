import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/watch_payjoin_policy_usecase.dart';

export '../domain/settings_failure.dart';
export '../presentation/settings_failure_l10n.dart';
export '../ui/settings_router.dart' show SettingsRoute;
export 'payjoin_disclaimer_dialog.dart';

/// Public settings contract consumed by other features.
class SettingsFacade {
  final SetPayjoinEnabledUsecase _setPayjoinEnabledUsecase;
  final WatchPayjoinPolicyUsecase _watchPayjoinPolicyUsecase;

  SettingsFacade({
    required this._setPayjoinEnabledUsecase,
    required this._watchPayjoinPolicyUsecase,
  });

  Future<Result<bool, SettingsFailure>> setPayjoinEnabled(
    bool enabled, {
    required Future<bool> Function() requestConsent,
  }) => _setPayjoinEnabledUsecase.execute(
    enabled,
    requestConsent: requestConsent,
  );

  Stream<({bool enabled, bool tradingEnabled, int minimumAmountSat})>
  watchPayjoinPolicy() {
    return _watchPayjoinPolicyUsecase.execute().map(
      (policy) => (
        enabled: policy.enabled,
        tradingEnabled: policy.tradingEnabled,
        minimumAmountSat: policy.minimumAmount.value.toInt(),
      ),
    );
  }

  Stream<int> watchPayjoinMinAmount() =>
      watchPayjoinPolicy().map((policy) => policy.minimumAmountSat).distinct();

  Stream<bool> watchPayjoinEnabled() =>
      watchPayjoinPolicy().map((policy) => policy.enabled).distinct();
}
