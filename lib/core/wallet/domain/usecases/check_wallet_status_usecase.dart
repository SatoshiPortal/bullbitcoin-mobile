import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/ports/electrum_server_port.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;

class TheDirtyUsecase {
  TheDirtyUsecase(
    this._settingsRepository,
    this._electrumServerPort,
    this._bitcoinWalletRepository,
  );
  final SettingsRepository _settingsRepository;
  final ElectrumServerPort _electrumServerPort;
  final BitcoinWalletRepository _bitcoinWalletRepository;

  Future<({BigInt satoshis, int transactions})> call({
    required bip39.Mnemonic mnemonic,
    required ScriptType scriptType,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;

      final electrumServers = await _electrumServerPort.getElectrumServers(
        isTestnet: isTestnet,
        isLiquid: false,
      );

      for (var i = 0; i < electrumServers.length; i++) {
        try {
          return await _bitcoinWalletRepository.dryScan(
            entropy: mnemonic.entropy,
            passphrase: mnemonic.passphrase,
            scriptType: scriptType,
            isTestnet: isTestnet,
            electrumServer: electrumServers[i],
          );
        } catch (e) {
          log.warning('Failed to sync with ${electrumServers[i].url}: $e');
          if (i == electrumServers.length - 1) {
            throw Exception('All Electrum servers failed to sync.');
          }
        }
      }
      throw Exception('No Electrum servers configured.');
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      throw CheckWalletStatusException(e.toString());
    }
  }
}

class CheckWalletStatusException extends BullException {
  CheckWalletStatusException(super.message);
}
