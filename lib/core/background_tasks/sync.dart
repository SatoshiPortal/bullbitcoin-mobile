import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_settings_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_server_model.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/logger.dart' show Logger;
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_facade.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:lwk/lwk.dart';

class Sync {
  static Future<void> bitcoin(
    SqliteDatabase sqlite,
    Logger log,
    List<ElectrumServerModel> electrumServers,
    Environment environment,
  ) async {
    final walletMetadataDatasource = WalletMetadataDatasource(sqlite: sqlite);
    final electrumSettingsDatasource = ElectrumSettingsStorageDatasource(
      sqlite: sqlite,
    );

    final electrumServer = electrumServers.first;

    final allMetadatas = await walletMetadataDatasource.fetchAll();
    final metadatas =
        allMetadatas
            .where(
              (m) =>
                  m.isLiquid == false && m.isTestnet == environment.isTestnet,
            )
            .toList();

    final electrumSettings = await electrumSettingsDatasource.fetchByNetwork(
      ElectrumServerNetwork.fromEnvironment(
        isTestnet: environment.isTestnet,
        isLiquid: false,
      ),
    );

    for (final metadata in metadatas) {
      final wallet = WalletModel.publicBdk(
        externalDescriptor: metadata.externalPublicDescriptor,
        internalDescriptor: metadata.internalPublicDescriptor,
        isTestnet: metadata.isTestnet,
        id: metadata.id,
      );
      await BdkFacade.sync(wallet, electrumServer, electrumSettings);
      log.fine('Bitcoin Wallet ${wallet.id} synced successfully');
    }
  }

  static Future<void> liquid(
    SqliteDatabase sqlite,
    Logger log,
    List<ElectrumServerModel> electrumServers,
    Environment environment,
  ) async {
    await LibLwk.init();

    final walletMetadataDatasource = WalletMetadataDatasource(sqlite: sqlite);
    final electrumSettingsDatasource = ElectrumSettingsStorageDatasource(
      sqlite: sqlite,
    );

    final electrumServer = electrumServers.first;

    final allMetadatas = await walletMetadataDatasource.fetchAll();
    final metadatas =
        allMetadatas
            .where(
              (m) => m.isLiquid == true && m.isTestnet == environment.isTestnet,
            )
            .toList();

    final electrumSettings = await electrumSettingsDatasource.fetchByNetwork(
      ElectrumServerNetwork.fromEnvironment(
        isTestnet: environment.isTestnet,
        isLiquid: true,
      ),
    );

    for (final metadata in metadatas) {
      final wallet = WalletModel.publicLwk(
        combinedCtDescriptor: metadata.externalPublicDescriptor,
        isTestnet: metadata.isTestnet,
        id: metadata.id,
      );
      await LwkFacade.sync(wallet, electrumServer, electrumSettings);
      log.fine('Liquid Wallet ${wallet.id} synced successfully');
    }
  }
}
