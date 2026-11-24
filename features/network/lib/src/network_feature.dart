import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/storage.dart' show WalletBackupUsage;
import 'package:bull_tor/tor.dart';
import 'package:electrum/electrum.dart';
import 'package:fees/fees.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mempool/mempool.dart';
import 'package:preferences/preferences.dart';
import 'package:secrets/secrets.dart';
import 'package:silent/silent.dart';

import 'electrum_settings/create_electrum_settings_bloc.dart';
import 'electrum_settings/ui/electrum_settings_router.dart';
import 'mempool_settings/create_mempool_settings_cubit.dart';
import 'mempool_settings/router.dart';
import 'network_navigation.dart';
import 'status_check/domain/check_all_service_status_usecase.dart';
import 'status_check/domain/check_service_status_usecase.dart';
import 'status_check/domain/read_wallet_network_usecase.dart';
import 'status_check/status_session.dart';
import 'status_check/ui/service_status_page.dart';
import 'tor_settings/presentation/tor_settings_cubit.dart';
import 'tor_settings/public/tor_settings_scope.dart';
import 'tor_settings/tor_settings_locator.dart';
import 'tor_settings/ui/screens/tor_settings_screen.dart';
import 'tor_settings/ui/tor_settings_router.dart';

typedef NetworkRoutes = ({List<RouteBase> root, List<RouteBase> appSettings});

final class NetworkFeature {
  final NetworkStatus status;
  final NetworkRoutes routes;

  const NetworkFeature._({required this.status, required this.routes});

  static NetworkFeature mount({
    required GetIt services,
    required WalletInventory inventory,
    required Future<Result<WalletBackupUsage?, RecoverBullFailure>> Function(
      String,
    )
    readBackup,
    required Preferences preferences,
    required Silent silent,
  }) {
    setupTorSettings(services, preferences);
    final wallets = ReadWalletNetworkUsecase(
      inventory,
      preferences,
      readBackup,
    );

    // RecoverBull is registered later in foreground startup. Resolve it when
    // a screen opens its status session.
    final status = buildNetworkStatus(
      () => CheckServiceStatusUsecase(
        readDefaultNetwork: wallets.defaultNetwork,
        checkAllServiceStatusUsecase: CheckAllServiceStatusUsecase(
          electrumServers: services<Electrum>().servers,
          getIndexPrice: Pricer.getIndexPrice,
          payjoinPolicy: services<PayjoinPolicyAccess>(),
          payjoinDiagnostics: services<PayjoinDiagnostics>(),
          fees: services<Fees>(),
          isTorRequired: wallets.requiresTor,
          checkServerConnection: services<RecoverBullFacade>().checkServer,
          preferences: preferences,
          tor: services<Tor>(),
          silent: silent,
        ),
      ),
    );

    return NetworkFeature._(
      status: status,
      routes: (
        root: List.unmodifiable([
          ElectrumSettingsRouter.route(
            createBloc: () =>
                createElectrumSettingsBloc(services<Electrum>(), preferences),
            createTorCubit: services.get<TorSettingsCubit>,
          ),
          MempoolSettingsRoute.route(
            () => createMempoolSettingsCubit(services<Mempool>(), preferences),
          ),
          GoRoute(
            path: '/service-status',
            name: serviceStatusRouteName,
            builder: (_, _) => ServiceStatusPage(status: status),
          ),
        ]),
        appSettings: List.unmodifiable([
          GoRoute(
            name: TorSettingsRoute.torSettings.name,
            path: TorSettingsRoute.torSettings.path,
            builder: (_, _) => TorSettingsScope(
              createCubit: services.get<TorSettingsCubit>,
              child: const TorSettingsScreen(),
            ),
          ),
        ]),
      ),
    );
  }
}
