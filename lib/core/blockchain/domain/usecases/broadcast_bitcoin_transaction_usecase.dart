import 'package:bb_mobile/core/blockchain/data/repository/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/transactions/data/datasources/send_timestamp_datasource.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:convert/convert.dart';

class BroadcastBitcoinTransactionUsecase {
  final BitcoinBlockchainRepository _bitcoinBlockchain;
  final SettingsRepository _settingsRepository;
  final SendTimestampDatasource _sendTimestampDatasource;

  BroadcastBitcoinTransactionUsecase({
    required BitcoinBlockchainRepository bitcoinBlockchainRepository,
    required this._settingsRepository,
    required this._sendTimestampDatasource,
  }) : _bitcoinBlockchain = bitcoinBlockchainRepository;

  Future<String> execute(String transaction, {required bool isPsbt}) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;

      final txid = isPsbt
          ? await _bitcoinBlockchain.broadcastPsbt(
              transaction,
              isTestnet: isTestnet,
            )
          : await _bitcoinBlockchain.broadcastTransaction(
              hex.decode(transaction),
              isTestnet: isTestnet,
            );
      await _recordSendTimestamp(txid);
      return txid;
    } catch (e) {
      throw BroadcastTransactionException(e.toString());
    }
  }

  /// Records the broadcast moment so the transaction history can price the
  /// send at what it was worth when the user made it.
  ///
  /// A failure here must never fail the send: the money has already moved,
  /// and the only cost of losing the row is that the transaction falls back
  /// to confirmation-time anchoring, which is what every incoming
  /// transaction does anyway.
  Future<void> _recordSendTimestamp(String txid) async {
    try {
      await _sendTimestampDatasource.record(
        txid: txid,
        sentAt: DateTime.now().toUtc(),
      );
    } catch (e) {
      log.warning('Failed to record send timestamp for $txid', error: e);
    }
  }
}
