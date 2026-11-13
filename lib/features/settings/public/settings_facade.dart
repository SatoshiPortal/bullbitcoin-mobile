import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_force_app_store_wording_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_force_app_store_wording_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/watch_payjoin_policy_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart' show PayjoinAction;

export '../domain/settings_failure.dart';
export '../presentation/settings_failure_l10n.dart';
export '../ui/settings_router.dart' show SettingsRoute;
export 'payjoin_disclaimer_dialog.dart';

part '../ui/amount_preferences_binder.dart';

/// Public settings contract consumed by other features.
class SettingsFacade {
  static Widget amountScope({
    required Widget child,
    required GlobalKey<NavigatorState> navigatorKey,
  }) => _AmountPreferencesBinder(navigatorKey: navigatorKey, child: child);

  final SetPayjoinEnabledUsecase _setPayjoinEnabledUsecase;
  final WatchPayjoinPolicyUsecase _watchPayjoinPolicyUsecase;
  final GetForceAppStoreWordingUsecase _getForceAppStoreWordingUsecase;
  final SetForceAppStoreWordingUsecase _setForceAppStoreWordingUsecase;

  SettingsFacade({
    required this._setPayjoinEnabledUsecase,
    required this._watchPayjoinPolicyUsecase,
    required this._getForceAppStoreWordingUsecase,
    required this._setForceAppStoreWordingUsecase,
  });

  /// Development switch (reachable in Dev Mode only): whether the App Store
  /// vocabulary is forced on this device. Stored locally.
  Future<Result<bool, SettingsFailure>> isAppStoreWordingForced() =>
      _getForceAppStoreWordingUsecase.execute();

  Future<Result<void, SettingsFailure>> setAppStoreWordingForced(bool forced) =>
      _setForceAppStoreWordingUsecase.execute(forced);

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
