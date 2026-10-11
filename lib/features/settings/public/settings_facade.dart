import 'package:bull_payjoin/bull_payjoin.dart' show PayjoinAction;
import 'package:primitives/primitives.dart' show Result;
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/watch_payjoin_policy_usecase.dart';
import 'package:bb_mobile/features/settings/public/settings_entry_registry.dart';

export '../domain/settings_failure.dart';
export '../presentation/settings_failure_l10n.dart';
export '../ui/settings_router.dart' show SettingsRoute;
export 'payjoin_disclaimer_dialog.dart';
export 'settings_entry_registry.dart'
    show SettingsEntryContribution, SettingsEntrySection;
export 'wallet_registration_request.dart';

/// Public settings contract consumed by other features.
class SettingsFacade {
  final SetPayjoinEnabledUsecase _setPayjoinEnabledUsecase;
  final WatchPayjoinPolicyUsecase _watchPayjoinPolicyUsecase;
  final SettingsEntryRegistry _entryRegistry;

  SettingsFacade({
    required this._setPayjoinEnabledUsecase,
    required this._watchPayjoinPolicyUsecase,
    required SettingsEntryRegistry entryRegistry,
  }) : _entryRegistry = entryRegistry; // ignore: prefer_initializing_formals

  void registerEntry(SettingsEntryContribution contribution) {
    _entryRegistry.register(contribution);
  }

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
