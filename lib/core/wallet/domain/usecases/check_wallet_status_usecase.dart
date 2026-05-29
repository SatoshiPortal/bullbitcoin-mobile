import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;

class CheckWalletStatusUsecase {
  CheckWalletStatusUsecase(
    this._settingsRepository,
    this._serversPort,
    this._bitcoinWalletRepository,
  );
  final SettingsRepository _settingsRepository;
  final ElectrumServersPort _serversPort;
  final BitcoinWalletRepository _bitcoinWalletRepository;

  Future<({BigInt satoshis, int transactions})> call({
    required bip39.Mnemonic mnemonic,
    required ScriptType scriptType,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;

      return await _serversPort
          .runWithFallback<({BigInt satoshis, int transactions})>(
            network: ElectrumServerNetwork.fromEnvironment(
              isTestnet: isTestnet,
              isLiquid: false,
            ),
            operation: (connection) => _bitcoinWalletRepository.dryScan(
              entropy: mnemonic.entropy,
              passphrase: mnemonic.passphrase,
              scriptType: scriptType,
              isTestnet: isTestnet,
              electrumServer: connection,
            ),
          );
    } on ElectrumFallbackException {
      // Preserve the typed exception so callers retain the per-server
      // attempts (failure tier, urls, root-cause errors) for diagnostics.
      rethrow;
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      throw CheckWalletStatusException(e.toString());
    }
  }
}

class CheckWalletStatusException extends BullException {
  CheckWalletStatusException(super.message);
}
