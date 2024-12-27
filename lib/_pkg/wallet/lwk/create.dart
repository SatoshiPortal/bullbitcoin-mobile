import 'dart:io';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:lwk_dart/lwk_dart.dart' as lwk;
import 'package:path_provider/path_provider.dart';

class LWKCreate {
  Future<(lwk.Wallet?, Err?)> loadPublicLwkWallet(Wallet wallet) async {
    try {
      // throw 'cool';

      final network = wallet.network == BBNetwork.Mainnet
          ? lwk.Network.mainnet
          : lwk.Network.testnet;

      final appDocDir = await getApplicationDocumentsDirectory();
      final String dbDir =
          '${appDocDir.path}/${wallet.getWalletStorageString()}';

      final descriptor = lwk.Descriptor(
        ctDescriptor: wallet.externalPublicDescriptor,
      );

      final w = await lwk.Wallet.init(
        network: network,
        dbpath: dbDir,
        descriptor: descriptor,
      );

      return (w, null);
    } catch (e) {
      try {
        if (e.toString().contains(
              'LwkError(msg: UpdateOnDifferentStatus { wollet_status: ',
            )) {
          final appDocDir = await getApplicationDocumentsDirectory();
          final String dbDir =
              '${appDocDir.path}/${wallet.getWalletStorageString()}';
          // delete dbDir
          final Directory dbDirect = Directory(dbDir);
          if (dbDirect.existsSync()) {
            await dbDirect.delete(recursive: true);
          }
        }
      } catch (e) {
        return (
          null,
          Err(
            e.toString(),
            title: 'Error occurred while creating wallet',
            solution: 'Please try again.',
          )
        );
      }
      return (
        null,
        Err(
          e.toString(),
          title: 'Error occurred while creating wallet',
          solution: 'Please try again.',
        )
      );
    }
  }
}
