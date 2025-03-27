import 'package:bb_mobile/core/data/repositories/boltz_swap_repository_impl.dart';
import 'package:bb_mobile/core/data/services/mnemonic_seed_factory_impl.dart';
import 'package:bb_mobile/core/data/services/payjoin_watcher_service_impl.dart';
import 'package:bb_mobile/core/data/services/swap_watcher_impl.dart';
import 'package:bb_mobile/core/data/services/wallet_manager_service_impl.dart';
import 'package:bb_mobile/core/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/core/domain/services/mnemonic_seed_factory.dart';
import 'package:bb_mobile/core/domain/services/payjoin_watcher_service.dart';
import 'package:bb_mobile/core/domain/services/swap_watcher_service.dart';
import 'package:bb_mobile/core/domain/services/wallet_manager_service.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/locator.dart';

Future<void> registerServices() async {
  // add swap watcher service
  locator.registerLazySingleton<SwapWatcherService>(
    () => SwapWatcherServiceImpl(
      walletManager: locator<WalletManagerService>(),
      boltzRepo: locator<SwapRepository>(
        instanceName:
            LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
      ) as BoltzSwapRepositoryImpl,
    ),
    instanceName: LocatorInstanceNameConstants.boltzSwapWatcherInstanceName,
  );

  // add swap watcher service
  locator.registerLazySingleton<SwapWatcherService>(
    () => SwapWatcherServiceImpl(
      walletManager: locator<WalletManagerService>(),
      boltzRepo: locator<SwapRepository>(
        instanceName:
            LocatorInstanceNameConstants.boltzTestnetSwapRepositoryInstanceName,
      ) as BoltzSwapRepositoryImpl,
    ),
    instanceName:
        LocatorInstanceNameConstants.boltzTestnetSwapWatcherInstanceName,
  );

  // Factories, managers or services responsible for handling specific logic
  locator.registerLazySingleton<MnemonicSeedFactory>(
    () => const MnemonicSeedFactoryImpl(),
  );
  locator.registerLazySingleton<WalletManagerService>(
    () => WalletManagerServiceImpl(
      walletMetadataRepository: locator<WalletMetadataRepository>(),
      seedRepository: locator<SeedRepository>(),
      electrumServerRepository: locator<ElectrumServerRepository>(),
    ),
  );
  locator.registerLazySingleton<PayjoinWatcherService>(
    () => PayjoinWatcherServiceImpl(
      payjoinRepository: locator<PayjoinRepository>(),
      electrumServerRepository: locator<ElectrumServerRepository>(),
      settingsRepository: locator<SettingsRepository>(),
      walletManagerService: locator<WalletManagerService>(),
    ),
  );
}
