import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:path_provider/path_provider.dart';

class BdkWalletFactory {
  const BdkWalletFactory();

  String _getHexId(String walletId) {
    final codeUnits = walletId.codeUnits;
    final buffer = StringBuffer();
    for (final unit in codeUnits) {
      buffer.write(unit.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  Future<String> _getDbPath(String dbName) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$dbName';
  }

  Future<bdk.Wallet> createWallet(Wallet wallet) async {
    if (!wallet.network.isBitcoin) {
      throw ArgumentError('BdkWalletFactory can only create Bitcoin wallets');
    }

    final network = wallet.network.isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;

    final external = await bdk.Descriptor.create(
      descriptor: wallet.externalPublicDescriptor,
      network: network,
    );
    final internal = await bdk.Descriptor.create(
      descriptor: wallet.internalPublicDescriptor,
      network: network,
    );

    // Use the same path generation as BdkWalletDatasource
    final dbName = _getHexId(wallet.id);
    final dbPath = await _getDbPath(dbName);
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