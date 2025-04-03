import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/payjoin/data/services/payjoin_watcher_service_impl.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/services/payjoin_watcher_service.dart';
import 'package:bb_mobile/core/seed/data/services/mnemonic_seed_factory_impl.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/services/mnemonic_seed_factory.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository_impl.dart';
import 'package:bb_mobile/core/swaps/data/services/swap_watcher_impl.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/services/swap_watcher_service.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/services/wallet_manager_service_impl.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_manager_service.dart';
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
      walletManagerService: locator<WalletManagerService>(),
    ),
  );
}
