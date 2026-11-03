import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:bull_ark/src/domain/entities/ark_server_config.dart';
import 'package:primitives/primitives.dart';

/// Owns the native bark [bark.Wallet]. Throws bark's exceptions; the
/// repository maps them.
class BarkWalletDatasource {
  bark.Wallet? _wallet;

  bool get isOpen => _wallet != null;

  Future<void> open({
    required String mnemonic,
    required ArkServerConfig config,
    required String datadir,
  }) async {
    await close();
    _wallet = await bark.Wallet.open(
      network: _network(config.network),
      mnemonicOrSeed: mnemonic,
      config: bark.Config(
        serverAddress: config.serverUrl.toString(),
        esploraAddress: config.esploraUrl.toString(),
      ),
      args: bark.WalletOpenArgs(datadir: datadir, runDaemon: false),
    );
  }

  Future<void> close() async {
    final wallet = _wallet;
    _wallet = null;
    wallet?.dispose();
  }

  Future<void> sync() => _require().sync_();

  Future<bark.Balance> balance() => _require().balance();

  Future<String> newAddress() => _require().newAddress();

  bark.Wallet _require() {
    final wallet = _wallet;
    if (wallet == null) throw const BarkWalletNotOpenException();
    return wallet;
  }

  static bark.Network _network(BitcoinNetwork network) => switch (network) {
    BitcoinNetwork.mainnet => bark.Network.bitcoin,
    BitcoinNetwork.testnet => bark.Network.testnet,
    BitcoinNetwork.signet => bark.Network.signet,
    BitcoinNetwork.regtest => bark.Network.regtest,
  };
}

class BarkWalletNotOpenException implements Exception {
  const BarkWalletNotOpenException();
}
