import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/storage/sqlite_datasource.dart';

extension PayjoinSenderModelX on PayjoinSenderModel {
  bool get isExpireAtPassed =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 > expireAt;

  PayjoinSender toEntity() {
    return PayjoinSender(
      status:
          isCompleted
              ? PayjoinStatus.completed
              : isExpired
              ? PayjoinStatus.expired
              : proposalPsbt != null
              ? PayjoinStatus.proposed
              : PayjoinStatus.requested,
      uri: uri,
      walletId: walletId,
      originalPsbt: originalPsbt,
      originalTxId: originalTxId,
      proposalPsbt: proposalPsbt,
      txId: txId,
    );
  }
}
