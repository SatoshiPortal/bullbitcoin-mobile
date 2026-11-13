import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/status/domain/ports/electrum_connectivity_port.dart';
import 'package:bb_mobile/features/status_check/domain/check_all_service_status_usecase.dart';
import 'package:bb_mobile/core/status/interface_adapters/adapter/electrum_connectivity_adapter.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:get_it/get_it.dart';
import 'package:bull_tor/tor.dart';

class StatusLocator {
  static void setup(GetIt locator) {
    // Port
    locator.registerFactory<ElectrumConnectivityPort>(
      () => ElectrumConnectivityAdapter(
        electrumServersPort: locator<ElectrumServersPort>(),
        serverStatusPort: locator<ServerStatusPort>(),
      ),
    );

    // Usecase
    locator.registerFactory<CheckAllServiceStatusUsecase>(
      () => CheckAllServiceStatusUsecase(
        getIndexPrice: Pricer.getIndexPrice,
        payjoinPolicy: locator<PayjoinPolicyAccess>(),
        payjoinDiagnostics: locator<PayjoinDiagnostics>(),
        feesRepository: locator<FeesRepository>(),
        electrumConnectivityPort: locator<ElectrumConnectivityPort>(),
        walletRepository: locator<WalletRepository>(),
        ensureTorReadyUsecase: locator<EnsureTorReadyUsecase>(),
        checkServerConnection: locator<RecoverBullFacade>().checkServer,
        settingsRepository: locator<SettingsRepository>(),
        tor: locator<Tor>(),
      ),
    );
  }
}
