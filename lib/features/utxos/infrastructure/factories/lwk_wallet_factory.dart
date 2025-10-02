import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:lwk/lwk.dart' as lwk;
import 'package:path_provider/path_provider.dart';

// TODO: Move this to a shared folder as it can be reused by all features that require
//  Lwk wallet calls.
class LwkWalletFactory {
  const LwkWalletFactory();

  String _getHexId(String walletId) {
    final codeUnits = walletId.codeUnits;
    final buffer = StringBuffer();
    for (final unit in codeUnits) {
      buffer.write(unit.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  Future<String> _getDbPath(String dbName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/$dbName';
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  Future<lwk.Wallet> createWallet(Wallet wallet) async {
    if (!wallet.network.isLiquid) {
      throw ArgumentError('LwkWalletFactory can only create Liquid wallets');
    }

    try {
      final network =
          wallet.network.isTestnet ? lwk.Network.testnet : lwk.Network.mainnet;

      final descriptor = lwk.Descriptor(
        ctDescriptor: wallet.externalPublicDescriptor,
      );

      // Use the same path generation as LwkWalletDatasource which should be deprecated
      final dbName = _getHexId(wallet.id);
      final dbPath = await _getDbPath(dbName);

      final lwkWallet = await lwk.Wallet.init(
        network: network,
        dbpath: dbPath,
        descriptor: descriptor,
      );

      return lwkWallet;
    } catch (e) {
      if (e is lwk.LwkError) {
        throw Exception(e.msg);
      } else {
        rethrow;
      }
    }
  }
}
