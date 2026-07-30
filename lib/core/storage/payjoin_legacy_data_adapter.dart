import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bull_payjoin/bull_payjoin.dart';

final class PayjoinLegacyDataAdapter implements PayjoinLegacyDataPort {
  final SqliteDatabase _database;

  const PayjoinLegacyDataAdapter(this._database);

  @override
  Future<PayjoinLegacySnapshot> readSnapshot() async {
    final senders = await _database.select(_database.payjoinSenders).get();
    final receivers = await _database.select(_database.payjoinReceivers).get();
    final settings = await _database.select(_database.settings).getSingle();
    return PayjoinLegacySnapshot(
      sourceSchemaVersion: SqliteDatabase.currentSchemaVersion,
      senders: senders
          .map(
            (row) => PayjoinLegacySender(
              uri: row.uri,
              isTestnet: row.isTestnet,
              protocolState: row.sender,
              walletId: row.walletId,
              originalPsbt: row.originalPsbt,
              originalTransactionId: row.originalTxId,
              amountSat: row.amountSat,
              createdAt: row.createdAt,
              expireAfterSec: row.expireAfterSec,
              proposalPsbt: row.proposalPsbt,
              transactionId: row.txId,
              isExpired: row.isExpired,
              isCompleted: row.isCompleted,
              isAborted: row.isAborted,
            ),
          )
          .toList(),
      receivers: receivers
          .map(
            (row) => PayjoinLegacyReceiver(
              id: row.id,
              address: row.address,
              isTestnet: row.isTestnet,
              protocolState: row.receiver,
              walletId: row.walletId,
              payjoinUri: row.pjUri,
              maximumFeeRateSatPerVbyte: row.maxFeeRateSatPerVb,
              createdAt: row.createdAt,
              expireAfterSec: row.expireAfterSec,
              originalTransaction: row.originalTxBytes,
              originalTransactionId: row.originalTxId,
              amountSat: row.amountSat,
              proposalPsbt: row.proposalPsbt,
              transactionId: row.txId,
              isExpired: row.isExpired,
              isCompleted: row.isCompleted,
              isAborted: row.isAborted,
            ),
          )
          .toList(),
      policy: PayjoinLegacyPolicy(
        enabled: settings.payjoinEnabled,
        minimumAmountSat: settings.payjoinMinAmountSat,
        sessionLifetimeSeconds: settings.payjoinExpireAfterSec,
      ),
    );
  }
}
