import 'package:bb_mobile/core/ark/usecases/fetch_ark_secret_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/check_for_online_electrum_servers_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core/fees/data/fees_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/status/domain/ports/electrum_connectivity_port.dart';
import 'package:bb_mobile/core/status/domain/usecases/check_all_service_status_usecase.dart';
import 'package:bb_mobile/core/status/interface_adapters/adapter/electrum_connectivity_adapter.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/locator.dart';

class StatusLocator {
  static void setup() {
    // Port
    locator.registerFactory<ElectrumConnectivityPort>(
      () => ElectrumConnectivityAdapter(
        checkForOnlineElectrumServersUsecase:
            locator<CheckForOnlineElectrumServersUsecase>(),
      ),
    );

    // Usecase
    locator.registerFactory<CheckAllServiceStatusUsecase>(
      () => CheckAllServiceStatusUsecase(
        mainnetBoltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        testnetBoltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
        exchangeRateRepository: locator<ExchangeRateRepository>(
          instanceName: 'mainnetExchangeRateRepository',
        ),
        payjoinRepository: locator<PayjoinRepository>(),
        feesRepository: locator<FeesRepository>(),
        electrumConnectivityPort: locator<ElectrumConnectivityPort>(),
        recoverBullRepository: locator<RecoverBullRepository>(),
        walletRepository: locator<WalletRepository>(),
        settingsRepository: locator<SettingsRepository>(),
        fetchArkSecretUsecase: locator<FetchArkSecretUsecase>(),
      ),
    );
  }
}
