import 'package:bb_mobile/features/electrum_settings/domain/regtest_electrum_profile.dart';

export '../domain/regtest_electrum_profile.dart';

import 'package:bb_mobile/features/electrum_settings/domain/electrum_failure.dart';
import 'package:primitives/primitives.dart';

export '../domain/electrum_failure.dart';

import 'package:bb_mobile/features/electrum_settings/frameworks/ui/routing/electrum_settings_router.dart';

export '../background_setup.dart' show createBackgroundWalletConnections;

class ElectrumSettingsFacade {
  final Future<Result<void, ElectrumFailure>> Function(
    NetworkEnv, {
    RegtestElectrumProfile? regtestProfile,
  })?
  _prepare;

  const ElectrumSettingsFacade({
    Future<Result<void, ElectrumFailure>> Function(
      NetworkEnv, {
      RegtestElectrumProfile? regtestProfile,
    })?
    prepareForegroundStorage,
  }) : _prepare = prepareForegroundStorage;

  /// Called after foreground migrations and authorized context capture.
  /// Only regtest provisions local defaults; no network transport is opened.
  Future<Result<void, ElectrumFailure>> prepareForegroundStorage(
    NetworkEnv environment, {
    RegtestElectrumProfile? regtestProfile,
  }) async {
    final prepare = _prepare;
    if (prepare == null) return const Err(ElectrumStorageNotReadyFailure());
    return prepare(environment, regtestProfile: regtestProfile);
  }

  String get settingsRouteName => ElectrumSettingsRoute.electrumSettings.name;
}
