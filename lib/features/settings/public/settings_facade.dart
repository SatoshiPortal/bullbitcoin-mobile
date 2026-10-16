import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/watch_payjoin_policy_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart' show PayjoinAction;

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

  /// Payjoin when receiving from other users, behind the disclaimer.
  Future<Result<bool, SettingsFailure>> setPayjoinReceiveEnabled(
    bool enabled, {
    required Future<bool> Function() requestConsent,
  }) => _setPayjoinEnabledUsecase.execute(
    PayjoinAction.receive,
    enabled,
    requestConsent: requestConsent,
  );

  Stream<({bool receiveEnabled, int minimumAmountSat})>
  watchPayjoinReceivePolicy() {
    return _watchPayjoinPolicyUsecase.execute().map(
      (policy) => (
        receiveEnabled: policy.receiveEnabled,
        minimumAmountSat: policy.minimumAmount.value.toInt(),
      ),
    );
  }

  Stream<int> watchPayjoinMinAmount() => watchPayjoinReceivePolicy()
      .map((policy) => policy.minimumAmountSat)
      .distinct();

  Stream<bool> watchPayjoinReceiveEnabled() => watchPayjoinReceivePolicy()
      .map((policy) => policy.receiveEnabled)
      .distinct();
}
