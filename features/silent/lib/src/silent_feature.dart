import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:silent/src/data/bwk_sp_account_repository.dart';
import 'package:silent/src/domain/usecases/get_sp_secret_usecase.dart';
import 'package:silent/src/presentation/sp_cubit.dart';
import 'package:silent/src/presentation/sp_settings_cubit.dart';
import 'package:silent/src/presentation/sp_setup_cubit.dart';
import 'package:silent/src/silent.dart';
import 'package:silent/src/silent_graph.dart';
import 'package:silent/src/ui/sp_router.dart';
import 'package:silent/src/watchers/sp_electrum_reconnect_watcher.dart';
import 'package:silent/src/watchers/sp_tip_watcher.dart';

typedef SilentRouteAccess = ({
  NetworkEnv? environment,
  bool isSuperuser,
  bool isDevModeEnabled,
});

final class SilentFeature {
  final GetIt _services;
  final String _walletHomePath;
  final SilentRouteAccess Function(BuildContext) _readRouteAccess;
  final List<RouteBase> routes;
  final bool _foregroundWatchers;

  SilentFeature._(
    this._services,
    this._walletHomePath,
    this._readRouteAccess,
    this.routes,
    this._foregroundWatchers,
  );

  static SilentFeature mount({
    required Preferences preferences,
    required Secrets secrets,
    required ReadSilentFingerprint readDefaultFingerprint,
    required SilentRouteAccess Function(BuildContext) readRouteAccess,
    required String walletHomePath,
    required void Function(BuildContext) openSend,
    required Widget Function(BuildContext, int) balanceBuilder,
    required Widget Function(BuildContext) settingsIconBuilder,
    bool startForegroundWatchers = false,
  }) {
    final services = GetIt.asNewInstance();
    services.registerSingleton(preferences);
    services.registerSingleton(secrets);
    SilentGraph.setup(
      services,
      readDefaultFingerprint: readDefaultFingerprint,
      startForegroundWatchers: startForegroundWatchers,
    );
    return SilentFeature._(
      services,
      walletHomePath,
      readRouteAccess,
      List.unmodifiable([
        SpSetupRouter.route(
          successRedirectPath: walletHomePath,
          createSetupCubit: services.get<SpSetupCubit>,
        ),
        SpRouter.route(
          createCubit: services.get<SpCubit>,
          createSettingsCubit: services.get<SpSettingsCubit>,
          openSend: openSend,
          exitRedirectPath: walletHomePath,
          balanceBuilder: balanceBuilder,
          settingsIconBuilder: settingsIconBuilder,
        ),
      ]),
      startForegroundWatchers,
    );
  }

  Silent get silent => _services<SilentCapability>();

  String? redirect(BuildContext context, String path) {
    if (!isSpPath(path)) return null;
    final access = _readRouteAccess(context);
    return spRedirect(
      path,
      environment: access.environment,
      isSuperuser: access.isSuperuser,
      isDevModeEnabled: access.isDevModeEnabled,
      isSpWalletSetup: _services<SilentCapability>().isSetUpNow,
      gateClosedRedirectPath: _walletHomePath,
    );
  }

  Future<Result<void, SilentFailure>> close() async {
    if (_foregroundWatchers) {
      await _services<SpTipWatcher>().dispose();
      await _services<SpElectrumReconnectWatcher>().dispose();
    }
    return _services<BwkSpAccountRepository>().close();
  }
}
