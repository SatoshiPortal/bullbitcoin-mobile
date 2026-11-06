import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/send/data/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:convert/convert.dart';
import 'package:bull_logger/bull_logger.dart';

class BroadcastBitcoinTransactionUsecase {
  final BitcoinBlockchainRepository _bitcoinBlockchain;
  final SettingsRepository _settingsRepository;

  BroadcastBitcoinTransactionUsecase({
    required BitcoinBlockchainRepository bitcoinBlockchainRepository,
    required this._settingsRepository,
  }) : _bitcoinBlockchain = bitcoinBlockchainRepository;

  Future<Network> captureNetwork() async => Network.fromEnvironment(
    environment: (await _settingsRepository.fetch()).environment.networkEnv,
    isLiquid: false,
  );

  Future<String> execute(
    String transaction, {
    required bool isPsbt,
    required Network network,
  }) async {
    try {
      if (!network.isMainnet) {
        final settings = await _settingsRepository.fetch();
        if (settings.isSuperuser != true || settings.isDevModeEnabled != true) {
          log.warning(
            'Broadcast refused network=${network.name} category=authorization',
          );
          throw const UnsupportedNetworkException();
        }
      }
      if (isPsbt) {
        return await _bitcoinBlockchain.broadcastPsbt(
          transaction,
          network: network,
        );
      }
      return await _bitcoinBlockchain.broadcastTransaction(
        hex.decode(transaction),
        network: network,
      );
    } catch (e) {
      throw BroadcastTransactionException(e.toString());
    }
  }
}
