import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/data/repository/electrum_server_repository_impl.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/state.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;

class TheDirtyUsecase {
  TheDirtyUsecase(this._settingsRepository, this._electrumServerRepository);
  final SettingsRepository _settingsRepository;
  final ElectrumServerRepository _electrumServerRepository;

  Future<({BigInt satoshis, int transactions})> call(
    Mnemonic mnemonic,
    ScriptType scriptType,
  ) async {
    try {
      final bip39Mnemonic = bip39.Mnemonic.fromWords(
        words: mnemonic.words,
        passphrase: mnemonic.passphrase,
        language: mnemonic.language,
      );

      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final network = Network.fromEnvironment(
        isTestnet: environment.isTestnet,
        isLiquid: false,
      );

      final bdkNetwork =
          environment.isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;

      final bdkMnemonic = await bdk.Mnemonic.fromEntropy(bip39Mnemonic.entropy);

      final descriptorSecretKey = await bdk.DescriptorSecretKey.create(
        mnemonic: bdkMnemonic,
        network: bdkNetwork,
        password: bip39Mnemonic.passphrase,
      );

      bdk.Descriptor? external;
      bdk.Descriptor? internal;

      switch (scriptType) {
        case ScriptType.bip84:
          external = await bdk.Descriptor.newBip84(
            secretKey: descriptorSecretKey,
            network: bdkNetwork,
            keychain: bdk.KeychainKind.externalChain,
          );
          internal = await bdk.Descriptor.newBip84(
            secretKey: descriptorSecretKey,
            network: bdkNetwork,
            keychain: bdk.KeychainKind.internalChain,
          );
        case ScriptType.bip49:
          external = await bdk.Descriptor.newBip49(
            secretKey: descriptorSecretKey,
            network: bdkNetwork,
            keychain: bdk.KeychainKind.externalChain,
          );
          internal = await bdk.Descriptor.newBip49(
            secretKey: descriptorSecretKey,
            network: bdkNetwork,
            keychain: bdk.KeychainKind.internalChain,
          );
        case ScriptType.bip44:
          external = await bdk.Descriptor.newBip44(
            secretKey: descriptorSecretKey,
            network: bdkNetwork,
            keychain: bdk.KeychainKind.externalChain,
          );
          internal = await bdk.Descriptor.newBip44(
            secretKey: descriptorSecretKey,
            network: bdkNetwork,
            keychain: bdk.KeychainKind.internalChain,
          );
      }

      final wallet = await bdk.Wallet.create(
        descriptor: external,
        changeDescriptor: internal,
        network: bdkNetwork,
        databaseConfig: const bdk.DatabaseConfig.memory(),
      );

      final electrumServer = await _electrumServerRepository
          .getPrioritizedServer(network: network);

      final electrumServerModel = ElectrumServerModel.fromEntity(
        electrumServer,
      );

      final blockchain =
          await BdkBitcoinBlockchainDatasource.createBlockchainFromElectrumServer(
            electrumServerModel,
          );

      await wallet.sync(blockchain: blockchain);

      final balance = wallet.getBalance();
      final transactions = wallet.listTransactions(includeRaw: true);

      return (satoshis: balance.confirmed, transactions: transactions.length);
    } catch (e) {
      log.severe(e);
      throw CheckWalletStatusException(e.toString());
    }
  }
}

class CheckWalletStatusException implements Exception {
  final String message;

  CheckWalletStatusException(this.message);

  @override
  String toString() => message;
}
