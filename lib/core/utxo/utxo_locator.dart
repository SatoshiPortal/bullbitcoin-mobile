import 'package:bb_mobile/core/utxo/data/datasources/frozen_utxo_datasource.dart';
import 'package:bb_mobile/core/utxo/data/repositories/utxo_repository_impl.dart';
import 'package:bb_mobile/core/utxo/domain/repositories/utxo_repository.dart';
import 'package:bb_mobile/core/utxo/domain/usecases/get_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/locator.dart';

class UtxoLocator {
  static void registerDatasources() {
    locator.registerLazySingleton<FrozenUtxoDatasource>(
      () => LocalStorageFrozenUtxoDatasource(),
    );
  }

  static void registerRepositories() {
    locator.registerLazySingleton<UtxoRepository>(
      () => UtxoRepositoryImpl(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        bdkWalletDatasource: locator<BdkWalletDatasource>(),
        lwkWalletDatasource: locator<LwkWalletDatasource>(),
        frozenUtxoDatasource: locator<FrozenUtxoDatasource>(),
      ),
    );
  }

  static void registerUsecases() {
    locator.registerLazySingleton<GetUtxosUsecase>(
      () => GetUtxosUsecase(
        utxoRepository: locator<UtxoRepository>(),
      ),
    );
  }
}
