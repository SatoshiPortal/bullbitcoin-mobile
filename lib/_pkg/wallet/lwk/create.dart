import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:lwk_dart/lwk_dart.dart' as lwk;
import 'package:path_provider/path_provider.dart';

class LWKCreate {
  Future<(lwk.Wallet?, Err?)> loadPublicLwkWallet(Wallet wallet) async {
    try {
      final network =
          wallet.network == BBNetwork.Mainnet ? lwk.Network.Mainnet : lwk.Network.Testnet;

      final appDocDir = await getApplicationDocumentsDirectory();
      final String dbDir = '${appDocDir.path}/db';

      final w = await lwk.Wallet.create(
        network: network,
        dbPath: dbDir,
        descriptor: wallet.externalPublicDescriptor,
      );

      return (w, null);
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
