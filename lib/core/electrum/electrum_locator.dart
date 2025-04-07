import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/blockchain/data/datasources/lwk_liquid_blockchain_datasource.dart';
import 'package:bb_mobile/core/blockchain/data/repository/bitcoin_blockchain_repository_impl.dart';
import 'package:bb_mobile/core/blockchain/data/repository/liquid_blockchain_repository_impl.dart';
import 'package:bb_mobile/core/blockchain/domain/repositories/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/data/repository/electrum_server_repository_impl.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/hive_storage_datasource_impl.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/locator.dart';
import 'package:hive/hive.dart';

class ElectrumLocator {
  static Future<void> registerDatasources() async {
    final electrumServersBox =
        await Hive.openBox<String>(HiveBoxNameConstants.electrumServers);
    locator.registerLazySingleton<ElectrumServerStorageDatasource>(
      () => ElectrumServerStorageDatasource(
        electrumServerStorage:
            HiveStorageDatasourceImpl<String>(electrumServersBox),
      ),
    );
  }

  static void registerRepositories() {
    locator.registerLazySingleton<ElectrumServerRepository>(
      () => ElectrumServerRepositoryImpl(
        electrumServerStorageDatasource:
            locator<ElectrumServerStorageDatasource>(),
      ),
    );
  }
}
