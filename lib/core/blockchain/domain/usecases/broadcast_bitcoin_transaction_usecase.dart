import 'package:bb_mobile/core/blockchain/data/repository/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/record_unconfirmed_bitcoin_transaction_usecase.dart';
import 'package:convert/convert.dart';

class BroadcastBitcoinTransactionUsecase {
  final BitcoinBlockchainRepository _bitcoinBlockchain;
  final SettingsRepository _settingsRepository;
  final RecordUnconfirmedBitcoinTransactionUsecase
  _recordUnconfirmedBitcoinTransactionUsecase;

  BroadcastBitcoinTransactionUsecase({
    required BitcoinBlockchainRepository bitcoinBlockchainRepository,
    required this._settingsRepository,
    required this._recordUnconfirmedBitcoinTransactionUsecase,
  }) : _bitcoinBlockchain = bitcoinBlockchainRepository;

  /// [walletId], when given, is used only to best-effort record this
  /// transaction locally after a successful broadcast — see
  /// [RecordUnconfirmedBitcoinTransactionUsecase]. It never influences
  /// whether or how the broadcast itself happens.
  Future<String> execute(
    String transaction, {
    required bool isPsbt,
    String? walletId,
  }) async {
    final String txId;
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;

      txId = isPsbt
          ? await _bitcoinBlockchain.broadcastPsbt(
              transaction,
              isTestnet: isTestnet,
            )
          : await _bitcoinBlockchain.broadcastTransaction(
              hex.decode(transaction),
              isTestnet: isTestnet,
            );
    } catch (e) {
      throw BroadcastTransactionException(e.toString());
    }

    // The broadcast above already succeeded. Recording it locally (a
    // no-op for anything but a CBF wallet — see
    // UnconfirmedBitcoinTransactionRepository) is best-effort only: it must
    // never turn this already-successful network broadcast into a failure,
    // and must never trigger a rebroadcast. Any failure here is logged
    // with a fixed message and the failure/exception's runtime type only —
    // never the raw transaction, txid, or wallet id.
    if (walletId != null) {
      try {
        final result = await _recordUnconfirmedBitcoinTransactionUsecase
            .execute(
              walletId: walletId,
              transaction: transaction,
              isPsbt: isPsbt,
            );
        result.fold((_) {}, (failure) {
          log.warning(
            'Recording unconfirmed local broadcast failed: '
            '${failure.runtimeType}',
          );
        });
      } catch (e) {
        log.warning(
          'Recording unconfirmed local broadcast failed: ${e.runtimeType}',
        );
      }
    }

    return txId;
  }
}
