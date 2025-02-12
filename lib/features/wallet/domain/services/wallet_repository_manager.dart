import 'package:bb_mobile/features/wallet/data/repositories/bdk_wallet_repository_impl.dart';
import 'package:bb_mobile/features/wallet/data/repositories/lwk_wallet_repository_impl.dart';
import 'package:bb_mobile/features/wallet/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:lwk/lwk.dart' as lwk;
import 'package:path_provider/path_provider.dart';

abstract class WalletRepositoryManager {
  Future<void> registerWallet(WalletMetadata metadata);
  WalletRepository? getRepository(String walletId);
  List<WalletRepository> getAllRepositories();
}

class WalletRepositoryManagerImpl implements WalletRepositoryManager {
  final Map<String, WalletRepository> _repositories = {};

  @override
  Future<void> registerWallet(WalletMetadata metadata) async {
    final id = metadata.id;

    if (_repositories.containsKey(id)) {
      return;
    }

    _repositories[id] = await _createRepository(walletMetadata: metadata);
  }

  @override
  WalletRepository? getRepository(String id) {
    return _repositories[id];
  }

  @override
  List<WalletRepository> getAllRepositories() {
    return _repositories.values.toList();
  }

  Future<WalletRepository> _createRepository({
    required WalletMetadata walletMetadata,
  }) async {
    if (walletMetadata.network.isBitcoin) {
      final wallet = await _createPublicBdkWalletInstance(
        walletId: walletMetadata.id,
        network: walletMetadata.network,
        externalPublicDescriptor: walletMetadata.externalPublicDescriptor,
        internalPublicDescriptor: walletMetadata.internalPublicDescriptor,
      );

      return BdkWalletRepositoryImpl(
        id: walletMetadata.id,
        publicWallet: wallet,
      );
    } else {
      final wallet = await _createPublicLwkWalletInstance(
        walletId: walletMetadata.id,
        network: walletMetadata.network,
        externalPublicDescriptor: walletMetadata.externalPublicDescriptor,
      );
      return LwkWalletRepositoryImpl(
        id: walletMetadata.id,
        publicWallet: wallet,
      );
    }
  }

  Future<bdk.Wallet> _createPublicBdkWalletInstance({
    required String walletId,
    Network network = Network.bitcoinMainnet,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
  }) async {
    final bdkNetwork = network.bdkNetwork;

    final external = await bdk.Descriptor.create(
      descriptor: externalPublicDescriptor,
      network: bdkNetwork,
    );
    final internal = await bdk.Descriptor.create(
      descriptor: internalPublicDescriptor,
      network: bdkNetwork,
    );

    final appDocDir = await getApplicationDocumentsDirectory();
    final String dbDir = '${appDocDir.path}/$walletId';

    final dbConfig = bdk.DatabaseConfig.sqlite(
      config: bdk.SqliteDbConfiguration(path: dbDir),
    );

    final wallet = await bdk.Wallet.create(
      descriptor: external,
      changeDescriptor: internal,
      network: bdkNetwork,
      databaseConfig: dbConfig,
    );

    return wallet;
  }

  Future<lwk.Wallet> _createPublicLwkWalletInstance({
    required String walletId,
    Network network = Network.liquidMainnet,
    required String externalPublicDescriptor,
  }) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final String dbDir = '${appDocDir.path}/$walletId';

    final descriptor = lwk.Descriptor(
      ctDescriptor: externalPublicDescriptor,
    );

    final wallet = await lwk.Wallet.init(
      network: network.lwkNetwork,
      dbpath: dbDir,
      descriptor: descriptor,
    );

    return wallet;
  }
}

extension NetworkX on Network {
  bdk.Network get bdkNetwork {
    switch (this) {
      case Network.bitcoinMainnet:
        return bdk.Network.bitcoin;
      case Network.bitcoinTestnet:
        return bdk.Network.testnet;
      case Network.liquidMainnet:
      case Network.liquidTestnet:
        throw WrongNetworkException('Liquid network is not supported by BDK');
    }
  }

  lwk.Network get lwkNetwork {
    switch (this) {
      case Network.liquidMainnet:
        return lwk.Network.mainnet;
      case Network.liquidTestnet:
        return lwk.Network.testnet;
      case Network.bitcoinMainnet:
      case Network.bitcoinTestnet:
        throw WrongNetworkException('Bitcoin network is not supported by LWK');
    }
  }
}

class WrongNetworkException implements Exception {
  final String message;

  WrongNetworkException(this.message);
}
