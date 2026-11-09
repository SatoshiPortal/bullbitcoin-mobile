import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:primitives/primitives.dart' show Ok, Err;
import 'package:bb_mobile/features/send/data/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/features/send/domain/broadcast_failure.dart';
import 'package:bb_mobile/features/send/data/broadcast_failure_mapper.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:convert/convert.dart';
import 'package:bull_logger/bull_logger.dart';

class BroadcastBitcoinTransactionUsecase {
  final BitcoinBlockchainRepository _bitcoinBlockchain;
  final SettingsRepository _settingsRepository;
  final WalletFacade? _wallet;

  BroadcastBitcoinTransactionUsecase({
    required BitcoinBlockchainRepository bitcoinBlockchainRepository,
    required this._settingsRepository,
    this._wallet,
  }) : _bitcoinBlockchain = bitcoinBlockchainRepository;

  Future<Network> captureNetwork() async => Network.fromEnvironment(
    environment: (await _settingsRepository.fetch()).environment.networkEnv,
    isLiquid: false,
  );

  Future<String> execute(
    String transaction, {
    required bool isPsbt,
    required Network network,
    String? walletId,
  }) async {
    // Explicit foreign/imported broadcasts have no wallet context. They retain
    // their existing behavior and are outside local-wallet spend protection.
    if (walletId == null) {
      return _broadcast(transaction, isPsbt: isPsbt, network: network);
    }
    final wallet = _wallet;
    if (wallet == null) {
      throw const WalletSpendBlockedException(BitcoinSpendStatus.unavailable);
    }
    final result = await wallet.broadcastBitcoin(
      walletId,
      network.bitcoin,
      () => _broadcast(transaction, isPsbt: isPsbt, network: network),
    );
    return switch (result) {
      Ok(:final value) => value.txid,
      Err(failure: WalletSpendBlockedFailure(:final status)) =>
        throw WalletSpendBlockedException(status),
    };
  }

  Future<String> _broadcast(
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
          throw CategorizedBroadcastException(
            BroadcastFailureCategory.authorization,
          );
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
    } on Exception catch (e) {
      throw CategorizedBroadcastException(mapBroadcastFailure(e));
    }
  }
}
