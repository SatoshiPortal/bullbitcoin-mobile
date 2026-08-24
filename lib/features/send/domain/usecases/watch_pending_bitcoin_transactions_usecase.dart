import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/domain/pending_bitcoin_transaction.dart';
import 'package:bb_mobile/features/send/domain/repositories/pending_bitcoin_transaction_repository.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/validate_pending_bitcoin_transaction_usecase.dart';

class WatchPendingBitcoinTransactionsUsecase {
  final PendingBitcoinTransactionRepository _repository;
  final ValidatePendingBitcoinTransactionUsecase
  _validatePendingBitcoinTransactionUsecase;

  const WatchPendingBitcoinTransactionsUsecase(
    this._repository,
    this._validatePendingBitcoinTransactionUsecase,
  );

  Stream<Result<PendingBitcoinTransactionSnapshot, SendFailure>> execute(
    String walletId,
  ) => _repository.watchWallet(walletId).asyncMap((result) async {
    switch (result) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final validated = <PendingBitcoinTransaction>[];
        var invalidCount = value.invalidCount;
        for (final transaction in value.transactions) {
          switch (await _validatePendingBitcoinTransactionUsecase.execute(
            transaction,
          )) {
            case Ok(:final value):
              validated.add(value);
            case Err(failure: SendStoredTransactionInvalidFailure()):
              invalidCount++;
            case Err(:final failure):
              return Err(failure);
          }
        }
        return Ok(
          PendingBitcoinTransactionSnapshot(
            transactions: validated,
            invalidCount: invalidCount,
          ),
        );
    }
  });
}
