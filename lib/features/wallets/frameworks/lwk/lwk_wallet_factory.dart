import 'package:bb_mobile/core/primitives/network/network_environment.dart';
import 'package:lwk/lwk.dart' as lwk;
import 'package:path_provider/path_provider.dart';

class LwkWalletFactory {
  const LwkWalletFactory();

  Future<lwk.Wallet> createWallet({
    required int id,
    required LiquidNetworkEnvironment networkEnvironment,
    required String ctDescriptor,
  }) async {
    final network = networkEnvironment.isTestnet
        ? lwk.Network.testnet
        : lwk.Network.mainnet;

    final descriptor = lwk.Descriptor(ctDescriptor: ctDescriptor);

    final dbPath = await _getDbPath(id);

    final lwkWallet = await lwk.Wallet.init(
      network: network,
      dbpath: dbPath,
      descriptor: descriptor,
    );

    return lwkWallet;
  }

  Future<String> _getDbPath(int walletId) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$walletId';
  }
}
