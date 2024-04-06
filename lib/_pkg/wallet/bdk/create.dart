import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:path_provider/path_provider.dart';

class BDKCreate {
  Future<(bdk.Wallet?, Err?)> loadPublicBdkWallet(
    Wallet wallet,
  ) async {
    try {
      final network =
          wallet.network == BBNetwork.Testnet ? bdk.Network.Testnet : bdk.Network.Bitcoin;

      final external = await bdk.Descriptor.create(
        descriptor: wallet.externalPublicDescriptor,
        network: network,
      );
      final internal = await bdk.Descriptor.create(
        descriptor: wallet.internalPublicDescriptor,
        network: network,
      );

      final appDocDir = await getApplicationDocumentsDirectory();
      final String dbDir = appDocDir.path + '/${wallet.getWalletStorageString()}';

      final dbConfig = bdk.DatabaseConfig.sqlite(
        config: bdk.SqliteDbConfiguration(path: dbDir),
      );

      final bdkWallet = await bdk.Wallet.create(
        descriptor: external,
        changeDescriptor: internal,
        network: network,
        databaseConfig: dbConfig,
      );

      return (bdkWallet, null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while creating wallet',
          solution: 'Please try again.',
        )
      );
    }
  }
}
