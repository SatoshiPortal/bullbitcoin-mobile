import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/domain/pending_bitcoin_transaction.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:meta/meta.dart';

abstract interface class PendingBitcoinTransactionRepository {
  @useResult
  Future<Result<PendingBitcoinTransaction, SendFailure>> save(
    PendingBitcoinTransaction transaction, {
    int? expectedRevision,
  });

  @useResult
  Future<Result<PendingBitcoinTransaction?, SendFailure>> get(String id);

  Stream<Result<PendingBitcoinTransactionSnapshot, SendFailure>> watchWallet(
    String walletId,
  );

  @useResult
  Future<Result<void, SendFailure>> delete(
    String id, {
    required int expectedRevision,
  });
}
