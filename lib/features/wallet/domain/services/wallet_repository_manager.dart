import 'package:bb_mobile/features/wallet/data/repositories/bdk_wallet_repository_impl.dart';
import 'package:bb_mobile/features/wallet/data/repositories/lwk_wallet_repository_impl.dart';
import 'package:bb_mobile/features/wallet/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:lwk/lwk.dart' as lwk;
import 'package:path_provider/path_provider.dart';

abstract class WalletRepositoryManager {
  Future<void> registerWallet(
    WalletMetadata metadata, {
    required String blockchainUrl,
  });
  WalletRepository? getRepository(String walletId);
  List<WalletRepository> getAllRepositories();
}

class WalletRepositoryManagerImpl implements WalletRepositoryManager {
  final Map<String, WalletRepository> _repositories = {};

  @override
  Future<void> registerWallet(
    WalletMetadata metadata, {
    required String blockchainUrl,
  }) async {
    final id = metadata.id;

    if (_repositories.containsKey(id)) {
      return;
    }

    _repositories[id] = await _createRepository(
      walletMetadata: metadata,
      blockchainUrl: blockchainUrl,
    );
  }

  @override
  WalletRepository? getRepository(String id) {
    return _repositories[id];
  }

  @override
  List<WalletRepository> getAllRepositories() {
    return _repositories.values.toList();
  }

  Future<WalletRepository> _createRepository(
      {required WalletMetadata walletMetadata,
      required String blockchainUrl}) async {
    switch (walletMetadata.network) {
      case Network.bitcoin:
        final wallet = await _createPublicBdkWalletInstance(
          walletId: walletMetadata.id,
          environment: walletMetadata.environment,
          externalPublicDescriptor: walletMetadata.externalPublicDescriptor,
          internalPublicDescriptor: walletMetadata.internalPublicDescriptor,
        );

        return BdkWalletRepositoryImpl(
          id: walletMetadata.id,
          publicWallet: wallet,
        );
      case Network.liquid:
        final wallet = await _createPublicLwkWalletInstance(
          walletId: walletMetadata.id,
          environment: walletMetadata.environment,
          externalPublicDescriptor: walletMetadata.externalPublicDescriptor,
        );
        return LwkWalletRepositoryImpl(
            id: walletMetadata.id, publicWallet: wallet);
    }
  }

  Future<bdk.Wallet> _createPublicBdkWalletInstance({
    required String walletId,
    NetworkEnvironment environment = NetworkEnvironment.mainnet,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
  }) async {
    final network = environment.bdkNetwork;

    final external = await bdk.Descriptor.create(
      descriptor: externalPublicDescriptor,
      network: network,
    );
    final internal = await bdk.Descriptor.create(
      descriptor: internalPublicDescriptor,
      network: network,
    );

    final appDocDir = await getApplicationDocumentsDirectory();
    final String dbDir = '${appDocDir.path}/$walletId';

    final dbConfig = bdk.DatabaseConfig.sqlite(
      config: bdk.SqliteDbConfiguration(path: dbDir),
    );

    final wallet = await bdk.Wallet.create(
      descriptor: external,
      changeDescriptor: internal,
      network: network,
      databaseConfig: dbConfig,
    );

    return wallet;
  }

  Future<lwk.Wallet> _createPublicLwkWalletInstance({
    required String walletId,
    NetworkEnvironment environment = NetworkEnvironment.mainnet,
    required String externalPublicDescriptor,
  }) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final String dbDir = '${appDocDir.path}/$walletId';

    final descriptor = lwk.Descriptor(
      ctDescriptor: externalPublicDescriptor,
    );

    final wallet = await lwk.Wallet.init(
      network: environment.lwkNetwork,
      dbpath: dbDir,
      descriptor: descriptor,
    );

    return wallet;
  }
}

extension NetworkEnvironmentX on NetworkEnvironment {
  bdk.Network get bdkNetwork {
    switch (this) {
      case NetworkEnvironment.mainnet:
        return bdk.Network.bitcoin;
      case NetworkEnvironment.testnet:
        return bdk.Network.testnet;
    }
  }

  lwk.Network get lwkNetwork {
    switch (this) {
      case NetworkEnvironment.mainnet:
        return lwk.Network.mainnet;
      case NetworkEnvironment.testnet:
        return lwk.Network.testnet;
    }
  }
}
