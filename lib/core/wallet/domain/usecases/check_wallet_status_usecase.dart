import 'package:bb_mobile/core/electrum/domain/electrum_fallback_runner.dart';
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

      if (electrumServers.isEmpty) {
        throw Exception('No Electrum servers configured.');
      }

      return await runElectrumFallback<
        ElectrumServer,
        ({BigInt satoshis, int transactions})
      >(
        servers: electrumServers,
        urlOf: (server) => server.url,
        isCustomOf: (server) => server.isCustom,
        operation: (server) => _bitcoinWalletRepository.dryScan(
          entropy: mnemonic.entropy,
          passphrase: mnemonic.passphrase,
          scriptType: scriptType,
          isTestnet: isTestnet,
          electrumServer: server,
        ),
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
