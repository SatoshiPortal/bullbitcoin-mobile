import 'package:bb_mobile/core_deprecated/ark/usecases/fetch_ark_secret_usecase.dart';
import 'package:bb_mobile/core_deprecated/electrum/application/usecases/check_for_online_electrum_servers_usecase.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core_deprecated/fees/data/fees_repository.dart';
import 'package:bb_mobile/core_deprecated/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core_deprecated/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core_deprecated/settings/data/settings_repository.dart';
import 'package:bb_mobile/core_deprecated/status/domain/ports/electrum_connectivity_port.dart';
import 'package:bb_mobile/core_deprecated/status/domain/usecases/check_all_service_status_usecase.dart';
import 'package:bb_mobile/core_deprecated/status/interface_adapters/adapter/electrum_connectivity_adapter.dart';
import 'package:bb_mobile/core_deprecated/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core_deprecated/tor/data/usecases/tor_status_usecase.dart';
import 'package:bb_mobile/core_deprecated/utils/constants.dart';
import 'package:bb_mobile/core_deprecated/wallet/data/repositories/wallet_repository.dart';
import 'package:get_it/get_it.dart';

class StatusLocator {
  static void setup(GetIt locator) {
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
        torStatusUsecase: locator<TorStatusUsecase>(),
      ),
    );
  }
}
