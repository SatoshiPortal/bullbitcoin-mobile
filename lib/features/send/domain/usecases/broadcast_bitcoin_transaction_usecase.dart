import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/send/data/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:convert/convert.dart';
import 'package:bull_logger/bull_logger.dart';

class BroadcastBitcoinTransactionUsecase {
  final BitcoinBlockchainRepository _bitcoinBlockchain;
  final SettingsRepository _settingsRepository;
  final WalletUtxoRepository _walletUtxoRepository;

  BroadcastBitcoinTransactionUsecase({
    required BitcoinBlockchainRepository bitcoinBlockchainRepository,
    required this._settingsRepository,
    required this._walletUtxoRepository,
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
      await _requireNoFrozenInput(transaction, isPsbt: isPsbt);
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

  Future<void> _requireNoFrozenInput(
    String transaction, {
    required bool isPsbt,
  }) async {
    final tx = isPsbt
        ? await BitcoinTx.fromPsbt(transaction)
        : await BitcoinTx.fromBytes(hex.decode(transaction));
    final frozen = (await _walletUtxoRepository.getAllFrozenOutpoints())
        .map((outpoint) => '${outpoint.txId}:${outpoint.vout}')
        .toSet();
    if (tx.inputs.any(
      (input) => frozen.contains('${input.txid}:${input.vout}'),
    )) {
      throw const FrozenInputBroadcastException();
    }
  }
}

/// The transaction spends a coin the user froze; it is not broadcast.
class FrozenInputBroadcastException implements Exception {
  const FrozenInputBroadcastException();

  @override
  String toString() => 'The transaction spends a frozen coin';
}
