import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/blockchain/domain/ports/electrum_server_port.dart'
    as dirty_dependency;
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/ports/electrum_server_port.dart';
import 'package:bdk_dart/bdk.dart' as bdk;
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

      final bdkNetwork = environment.isTestnet
          ? bdk.Network.testnet
          : bdk.Network.bitcoin;

      final bdkMnemonic = bdk.Mnemonic.fromEntropy(
        entropy: Uint8List.fromList(mnemonic.entropy),
      );

      final descriptorSecretKey = bdk.DescriptorSecretKey(
        network: bdkNetwork,
        mnemonic: bdkMnemonic,
        password: mnemonic.passphrase,
      );

      bdk.Descriptor? external;
      bdk.Descriptor? internal;

      switch (scriptType) {
        case ScriptType.bip84:
          external = bdk.Descriptor.newBip84(
            secretKey: descriptorSecretKey,
            keychainKind: bdk.KeychainKind.external_,
            network: bdkNetwork,
          );
          internal = bdk.Descriptor.newBip84(
            secretKey: descriptorSecretKey,
            keychainKind: bdk.KeychainKind.internal,
            network: bdkNetwork,
          );
        case ScriptType.bip49:
          external = bdk.Descriptor.newBip49(
            secretKey: descriptorSecretKey,
            keychainKind: bdk.KeychainKind.external_,
            network: bdkNetwork,
          );
          internal = bdk.Descriptor.newBip49(
            secretKey: descriptorSecretKey,
            keychainKind: bdk.KeychainKind.internal,
            network: bdkNetwork,
          );
        case ScriptType.bip44:
          external = bdk.Descriptor.newBip44(
            secretKey: descriptorSecretKey,
            keychainKind: bdk.KeychainKind.external_,
            network: bdkNetwork,
          );
          internal = bdk.Descriptor.newBip44(
            secretKey: descriptorSecretKey,
            keychainKind: bdk.KeychainKind.internal,
            network: bdkNetwork,
          );
      }

      final wallet = bdk.Wallet(
        descriptor: external,
        changeDescriptor: internal,
        network: bdkNetwork,
        persister: bdk.Persister.newInMemory(),
        lookahead: 0,
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

          final fullScanRequest = wallet.startFullScan().build();
          final scanUpdate = blockchain.fullScan(
            request: fullScanRequest,
            stopGap: electrumServer.stopGap,
            batchSize: 20,
            fetchPrevTxouts: true,
          );
          wallet.applyUpdate(update: scanUpdate);
          break; // Exit the loop if sync is successful
        } catch (e) {
          log.warning(
            'Failed to sync with ${electrumServers[i].url}',
            error: e,
          );
          if (i == electrumServers.length - 1) {
            throw Exception('All Electrum servers failed to sync.');
          }
        }
      }

      final balance = wallet.balance();
      final transactions = wallet.transactions();

      return (
        satoshis: BigInt.from(balance.confirmed.toSat()),
        transactions: transactions.length,
      );
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      throw CheckWalletStatusException(e.toString());
    }
  }
}

class CheckWalletStatusException extends BullException {
  CheckWalletStatusException(super.message);
}
