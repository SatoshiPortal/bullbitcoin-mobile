import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/transactions/data/datasources/send_timestamp_datasource.dart';
import 'package:bull_logger/bull_logger.dart';

class BroadcastLiquidTransactionUsecase {
  final LiquidBlockchainRepository _liquidBlockchain;
  final SettingsRepository _settingsRepository;
  final SendTimestampDatasource _sendTimestampDatasource;

  BroadcastLiquidTransactionUsecase({
    required LiquidBlockchainRepository liquidBlockchainRepository,
    required this._settingsRepository,
    required this._sendTimestampDatasource,
  }) : _liquidBlockchain = liquidBlockchainRepository;

  Future<String> execute(String signedPset, {bool? isTestnet}) async {
    try {
      isTestnet ??= (await _settingsRepository.fetch()).environment.isTestnet;
      final txid = await _liquidBlockchain.broadcastTransaction(
        signedPset: signedPset,
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
