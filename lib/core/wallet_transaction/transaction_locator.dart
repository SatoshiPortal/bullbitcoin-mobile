import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet_transaction/data/repositories/wallet_transaction_repository_impl.dart';
import 'package:bb_mobile/core/wallet_transaction/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/core/wallet_transaction/domain/usecases/get_wallet_transactions_usecase.dart';
import 'package:bb_mobile/core/wallet_transaction/domain/usecases/watch_wallet_transaction_by_address_usecase.dart';
import 'package:bb_mobile/locator.dart';

class TransactionLocator {
  static void registerRepositories() {
    locator.registerLazySingleton<WalletTransactionRepository>(
      () => WalletTransactionRepositoryImpl(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        bdkWalletTransactionDatasource: locator<BdkWalletDatasource>(),
        lwkWalletTransactionDatasource: locator<LwkWalletDatasource>(),
        electrumServerStorage: locator<ElectrumServerStorageDatasource>(),
      ),
    );
  }

  static void registerUsecases() {
    locator.registerFactory<GetWalletTransactionsUsecase>(
      () => GetWalletTransactionsUsecase(
        settingsRepository: locator<SettingsRepository>(),
        walletTransactionRepository: locator<WalletTransactionRepository>(),
        testnetSwapRepository: locator<SwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        mainnetSwapRepository: locator<SwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );

    locator.registerFactory<WatchWalletTransactionByAddressUsecase>(
      () => WatchWalletTransactionByAddressUsecase(
        walletTransactionRepository: locator<WalletTransactionRepository>(),
      ),
    );
  }
}
