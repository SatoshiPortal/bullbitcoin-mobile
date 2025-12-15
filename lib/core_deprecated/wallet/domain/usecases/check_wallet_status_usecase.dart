import 'package:bb_mobile/core_deprecated/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core_deprecated/blockchain/domain/ports/electrum_server_port.dart'
    as dirty_dependency;
import 'package:bb_mobile/core_deprecated/errors/bull_exception.dart';
import 'package:bb_mobile/core_deprecated/settings/data/settings_repository.dart';
import 'package:bb_mobile/core_deprecated/utils/logger.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/ports/electrum_server_port.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;

// This usecase has to be reworked, it has been implemented this way because of deadline
class TheDirtyUsecase {
  TheDirtyUsecase(this._settingsRepository, this._electrumServerPort);
  final SettingsRepository _settingsRepository;
  final ElectrumServerPort _electrumServerPort;

  Future<({BigInt satoshis, int transactions})> call({
    required bip39.Mnemonic mnemonic,
    required ScriptType scriptType,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final network = Network.fromEnvironment(
        isTestnet: environment.isTestnet,
        isLiquid: false,
      );

      final bdkNetwork =
          environment.isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;

      final bdkMnemonic = await bdk.Mnemonic.fromEntropy(mnemonic.entropy);

      final descriptorSecretKey = await bdk.DescriptorSecretKey.create(
        mnemonic: bdkMnemonic,
        network: bdkNetwork,
        password: mnemonic.passphrase,
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

      final electrumServers = await _electrumServerPort.getElectrumServers(
        isTestnet: network.isTestnet,
        isLiquid: network.isLiquid,
      );

      for (int i = 0; i < electrumServers.length; i++) {
        try {
          final electrumServer = electrumServers[i];
          final blockchain =
              await BdkBitcoinBlockchainDatasource.createBlockchainFromElectrumServer(
                dirty_dependency.ElectrumServer(
                  url: electrumServer.url,
                  socks5: electrumServer.socks5,
                  retry: electrumServer.retry,
                  timeout: electrumServer.timeout,
                  stopGap: electrumServer.stopGap,
                  validateDomain: electrumServer.validateDomain,
                  priority: electrumServer.priority,
                  isCustom: electrumServer.isCustom,
                ),
              );

          await wallet.sync(blockchain: blockchain);
          break; // Exit the loop if sync is successful
        } catch (e) {
          log.warning('Failed to sync with ${electrumServers[i].url}: $e');
          if (i == electrumServers.length - 1) {
            throw Exception('All Electrum servers failed to sync.');
          }
        }
      }

      final balance = wallet.getBalance();
      final transactions = wallet.listTransactions(includeRaw: true);

      return (satoshis: balance.confirmed, transactions: transactions.length);
    } catch (e) {
      log.severe(e);
      throw CheckWalletStatusException(e.toString());
    }
  }
}

class CheckWalletStatusException extends BullException {
  CheckWalletStatusException(super.message);
}
