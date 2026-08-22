import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_trading_enabled_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/watch_payjoin_policy_usecase.dart';

export '../domain/settings_failure.dart';
export '../presentation/settings_failure_l10n.dart';
export '../ui/settings_router.dart' show SettingsRoute;
export 'payjoin_disclaimer_dialog.dart';

/// Public settings contract consumed by other features.
class SettingsFacade {
  final SetPayjoinEnabledUsecase _setPayjoinEnabledUsecase;
  final SetPayjoinTradingEnabledUsecase _setPayjoinTradingEnabledUsecase;
  final WatchPayjoinPolicyUsecase _watchPayjoinPolicyUsecase;

  SettingsFacade({
    required this._setPayjoinEnabledUsecase,
    required this._setPayjoinTradingEnabledUsecase,
    required this._watchPayjoinPolicyUsecase,
  });

  Future<Result<bool, SettingsFailure>> setPayjoinEnabled(
    bool enabled, {
    required Future<bool> Function() requestConsent,
  }) => _setPayjoinEnabledUsecase.execute(
    enabled,
    requestConsent: requestConsent,
  );

  /// No consent step: trading payjoin ships ON and needs no disclaimer (the
  /// Bull Bitcoin exchange is already the trade's counterparty). Written
  /// through from the per-order toggles in the buy/sell/pay flows.
  Future<Result<bool, SettingsFailure>> setPayjoinTradingEnabled(
    bool enabled,
  ) => _setPayjoinTradingEnabledUsecase.execute(enabled);

  /// The per-order payjoin switch in a trade flow IS the global trading
  /// setting: flipping it persists the preference for every future trade too.
  /// A persist failure only costs the preference (the current order already
  /// follows the flipped switch), so it is logged rather than surfaced.
  Future<void> persistPayjoinTradingToggle(
    bool enabled, {
    required String flow,
  }) async {
    final result = await setPayjoinTradingEnabled(enabled);
    if (result case Err(:final failure)) {
      log.warning(
        'Failed to persist payjoin trading setting from $flow: '
        '${failure.logMessage}',
      );
    }
  }

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

  Stream<bool> watchPayjoinTradingEnabled() =>
      watchPayjoinPolicy().map((policy) => policy.tradingEnabled).distinct();

  Stream<int> watchPayjoinMinAmount() =>
      watchPayjoinPolicy().map((policy) => policy.minimumAmountSat).distinct();

  Stream<bool> watchPayjoinEnabled() =>
      watchPayjoinPolicy().map((policy) => policy.enabled).distinct();
}
