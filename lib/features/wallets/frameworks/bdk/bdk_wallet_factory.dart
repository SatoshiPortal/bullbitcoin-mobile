import 'package:bb_mobile/core/primitives/network/network_environment.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:path_provider/path_provider.dart';

// TODO: Move this to a shared/core folder as it can be reused by all features that require
//  Bdk wallet calls.
class BdkWalletFactory {
  const BdkWalletFactory();

  Future<String> _getDbPath(int walletId) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$walletId';
  }

  Future<bdk.Wallet> createWallet({
    required int id,
    required BitcoinNetworkEnvironment networkEnvironment,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
  }) async {
    final network = networkEnvironment.isTestnet
        ? bdk.Network.testnet
        : bdk.Network.bitcoin;

    final external = await bdk.Descriptor.create(
      descriptor: externalPublicDescriptor,
      network: network,
    );
    final internal = await bdk.Descriptor.create(
      descriptor: internalPublicDescriptor,
      network: network,
    );

    final dbPath = await _getDbPath(id);
    final dbConfig = bdk.DatabaseConfig.sqlite(
      config: bdk.SqliteDbConfiguration(path: dbPath),
    );

    final bdkWallet = await bdk.Wallet.create(
      descriptor: external,
      changeDescriptor: internal,
      network: network,
      databaseConfig: dbConfig,
    );

    return bdkWallet;
  }
}
