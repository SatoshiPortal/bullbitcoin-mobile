import 'package:bb_mobile/core_deprecated/electrum/frameworks/drift/models/electrum_server_model.dart';
import 'package:bb_mobile/core_deprecated/electrum/frameworks/drift/models/electrum_settings_model.dart';
import 'package:bb_mobile/core_deprecated/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:path_provider/path_provider.dart';

class BdkFacade {
  static Future<bdk.Wallet> createWallet(WalletModel walletModel) {
    if (walletModel is PublicBdkWalletModel) {
      return createPublicWallet(walletModel);
    } else if (walletModel is PrivateBdkWalletModel) {
      return createPrivateWallet(walletModel);
    } else {
      throw ArgumentError('Unsupported wallet model type');
    }
  }

  static Future<bdk.Wallet> createPublicWallet(WalletModel walletModel) async {
    if (walletModel is! PublicBdkWalletModel) {
      throw ArgumentError('Wallet must be of type PublicBdkWalletModel');
    }

    final network =
        walletModel.isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;

    final external = await bdk.Descriptor.create(
      descriptor: walletModel.externalDescriptor,
      network: network,
    );
    final internal = await bdk.Descriptor.create(
      descriptor: walletModel.internalDescriptor,
      network: network,
    );

    // Create the database configuration
    final dbPath = await _getDbPath(walletModel.dbName);
    final dbConfig = bdk.DatabaseConfig.sqlite(
      config: bdk.SqliteDbConfiguration(path: dbPath),
    );

    final wallet = await bdk.Wallet.create(
      descriptor: external,
      changeDescriptor: internal,
      network: network,
      databaseConfig: dbConfig,
    );

    return wallet;
  }

  static Future<bdk.Wallet> createPrivateWallet(WalletModel walletModel) async {
    if (walletModel is! PrivateBdkWalletModel) {
      throw ArgumentError('Wallet must be of type PrivateBdkWalletModel');
    }

    final network =
        walletModel.isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;

    final bdkMnemonic = await bdk.Mnemonic.fromString(walletModel.mnemonic);
    final secretKey = await bdk.DescriptorSecretKey.create(
      network: network,
      mnemonic: bdkMnemonic,
      password: walletModel.passphrase,
    );

    bdk.Descriptor? external;
    bdk.Descriptor? internal;

    switch (walletModel.scriptType) {
      case ScriptType.bip84:
        external = await bdk.Descriptor.newBip84(
          secretKey: secretKey,
          network: network,
          keychain: bdk.KeychainKind.externalChain,
        );
        internal = await bdk.Descriptor.newBip84(
          secretKey: secretKey,
          network: network,
          keychain: bdk.KeychainKind.internalChain,
        );
      case ScriptType.bip49:
        external = await bdk.Descriptor.newBip49(
          secretKey: secretKey,
          network: network,
          keychain: bdk.KeychainKind.externalChain,
        );
        internal = await bdk.Descriptor.newBip49(
          secretKey: secretKey,
          network: network,
          keychain: bdk.KeychainKind.internalChain,
        );
      case ScriptType.bip44:
        external = await bdk.Descriptor.newBip44(
          secretKey: secretKey,
          network: network,
          keychain: bdk.KeychainKind.externalChain,
        );
        internal = await bdk.Descriptor.newBip44(
          secretKey: secretKey,
          network: network,
          keychain: bdk.KeychainKind.internalChain,
        );
    }

    // Create the database configuration
    final dbPath = await _getDbPath(walletModel.dbName);
    final dbConfig = bdk.DatabaseConfig.sqlite(
      config: bdk.SqliteDbConfiguration(path: dbPath),
    );

    final wallet = await bdk.Wallet.create(
      descriptor: external,
      changeDescriptor: internal,
      network: network,
      databaseConfig: dbConfig,
    );

    return wallet;
  }

  static Future<String> _getDbPath(String dbName) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$dbName';
  }

  static Future<void> sync(
    WalletModel wallet,
    ElectrumServerModel electrumServer,
    ElectrumSettingsModel electrumSettings,
  ) async {
    final blockchain = await bdk.Blockchain.create(
      config: bdk.BlockchainConfig.electrum(
        config: bdk.ElectrumConfig(
          url: electrumServer.url,
          // Only set the socks5 if it's not empty,
          //  otherwise bdk will throw an error
          socks5:
              electrumSettings.socks5?.isNotEmpty == true
                  ? electrumSettings.socks5
                  : null,
          retry: electrumSettings.retry,
          timeout: electrumSettings.timeout,
          stopGap: BigInt.from(electrumSettings.stopGap),
          validateDomain: electrumSettings.validateDomain,
        ),
      ),
    );

    final bdkWallet = await BdkFacade.createWallet(wallet);
    await bdkWallet.sync(blockchain: blockchain);
  }
}
