import 'package:bb_mobile/core/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:bb_mobile/core/transaction/domain/repositories/transaction_repository.dart';
import 'package:bb_mobile/core/transaction/domain/usecases/get_transactions_usecase.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/locator.dart';

class TransactionLocator {
  static void registerRepositories() {
    locator.registerLazySingleton<TransactionRepository>(
      () => TransactionRepositoryImpl(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        bdkWalletDatasource: locator<BdkWalletDatasource>(),
        lwkWalletDatasource: locator<LwkWalletDatasource>(),
      ),
    );
  }

  static void registerUsecases() {
    locator.registerFactory<GetTransactionsUsecase>(
      () => GetTransactionsUsecase(
        transactionRepository: locator<TransactionRepository>(),
      ),
    );
  }
}
