import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/storage/sqlite_datasource.dart';

extension PayjoinReceiverModelX on PayjoinReceiverModel {
  bool get isExpireAtPassed =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 > expireAt;

  PayjoinReceiver toEntity() {
    return PayjoinReceiver(
      status:
          isCompleted
              ? PayjoinStatus.completed
              : isExpired
              ? PayjoinStatus.expired
              : proposalPsbt != null
              ? PayjoinStatus.proposed
              : originalTxBytes != null
              ? PayjoinStatus.requested
              : PayjoinStatus.started,
      id: id,
      pjUri: pjUri,
      walletId: walletId,
      originalTxBytes: originalTxBytes,
      originalTxId: originalTxId,
      amountSat: amountSat,
      proposalPsbt: proposalPsbt,
      txId: txId,
    );
  }
}
