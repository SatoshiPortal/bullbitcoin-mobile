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
  bool _foregroundWatchers = false;
  bool _suspended = false;
  bool _stopFailed = false;
  bool _restartWatchers = false;
  Future<void>? _suspending;

  SilentFeature._(
    this._services,
    this._walletHomePath,
    this._readRouteAccess,
    this.routes,
  );

  @visibleForTesting
  SilentFeature.forTesting(GetIt services)
    : this._(services, '/', (_) => throw UnimplementedError(), const []);

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
    SilentGraph.setup(services, readDefaultFingerprint: readDefaultFingerprint);
    final feature = SilentFeature._(
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
    );
    if (startForegroundWatchers) feature.startForegroundWatchers();
    return feature;
  }

  @visibleForTesting
  bool get foregroundWatchersStarted => _foregroundWatchers;

  void startForegroundWatchers() {
    if (_foregroundWatchers) return;
    SilentGraph.startForegroundWatchers(_services);
    _foregroundWatchers = true;
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

  /// Revokes the signing account now: nothing new opens, then the foreground
  /// watchers and the native account stop. Completes once the account is
  /// confirmed closed; a stop that fails throws and the account stays closed.
  Future<void> suspend() {
    final stopping = _suspending;
    if (stopping != null) return stopping;
    if (_suspended) return Future<void>.value();
    _suspended = true;
    _restartWatchers = _foregroundWatchers;
    final account = _services<BwkSpAccountRepository>();
    account.beginTeardown();
    return _suspending = _stop(account);
  }

  Future<void> _stop(BwkSpAccountRepository account) async {
    try {
      if (_foregroundWatchers) {
        _foregroundWatchers = false;
        await Future.wait([
          _services<SpTipWatcher>().dispose(),
          _services<SpElectrumReconnectWatcher>().dispose(),
        ]);
      }
      final outcome = await account.dispose();
      if (outcome case Err(:final failure)) {
        throw StateError('Silent account did not stop: ${failure.runtimeType}');
      }
    } catch (_) {
      _stopFailed = true;
      rethrow;
    } finally {
      _suspending = null;
    }
  }

  /// Lets the account open again and restarts the watchers [suspend] stopped.
  /// Does nothing until the stop is confirmed, or after a failed stop.
  void resume() {
    if (!_suspended || _suspending != null || _stopFailed) return;
    _suspended = false;
    _services<BwkSpAccountRepository>().endTeardown();
    if (_restartWatchers) startForegroundWatchers();
  }

  Future<Result<void, SilentFailure>> close() async {
    if (_foregroundWatchers) {
      await _services<SpTipWatcher>().dispose();
      await _services<SpElectrumReconnectWatcher>().dispose();
    }
    return _services<BwkSpAccountRepository>().close();
  }
}
