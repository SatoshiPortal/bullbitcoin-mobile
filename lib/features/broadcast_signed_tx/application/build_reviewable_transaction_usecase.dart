import 'package:bb_mobile/core/transactions/domain/domain_errors.dart';
import 'package:bb_mobile/core/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/core/transactions/domain/transaction_port.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/reviewable_transaction.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/transaction_review_failure.dart';
import 'package:meta/meta.dart';

/// Build a [ReviewableTransaction] from a domain [Transaction], resolving
/// each input's value by fetching the parent transaction via [TransactionPort].
///
/// Change output is left unresolved (`null`) since external transactions
/// don't carry wallet-side ownership data.
class BuildReviewableTransactionUsecase {
  final TransactionPort _transactionPort;

  BuildReviewableTransactionUsecase({required this._transactionPort});

  /// This use-case is the boundary: it catches the throwing [TransactionPort],
  /// maps the foreign error into a sanitized [TransactionReviewFailure], and
  /// returns a [Result]. The presentation layer never sees a foreign type.
  @useResult
  Future<Result<ReviewableTransaction, TransactionReviewFailure>> execute(
    Transaction tx,
  ) async {
    final resolvedInputs = <ResolvedInput>[];

    for (final input in tx.inputs) {
      try {
        final parentTx = await _transactionPort.fetch(txid: input.previousTxId);

        if (input.previousVout >= parentTx.outputs.length) {
          return Err(
            TransactionReviewInputResolutionFailure(
              parentTxId: input.previousTxId,
              vout: input.previousVout,
            ),
          );
        }

        final parentOutput = parentTx.outputs[input.previousVout];
        resolvedInputs.add(
          ResolvedInput(
            valueSat: parentOutput.valueSat,
            previousTxId: input.previousTxId,
            previousVout: input.previousVout,
            address: parentOutput.address,
          ),
        );
      } on TransactionPortError catch (e) {
        return Err(_mapPortError(e));
      } catch (e, st) {
        // Genuinely unexpected escape — the raw reason is born here, so it is
        // logged here (Sentry) and the UI shows a generic message.
        log.severe(
          message: 'Unexpected failure building reviewable transaction',
          error: e,
          trace: st,
        );
        return Err(TransactionReviewUnexpectedFailure(e.toString()));
      }
    }

    return Ok(
      ReviewableTransaction(transaction: tx, resolvedInputs: resolvedInputs),
    );
  }

  TransactionReviewFailure _mapPortError(TransactionPortError e) => switch (e) {
        TransactionPortFetchFailed(:final txid, :final message) =>
          TransactionReviewFetchFailure(txid: txid, logMessage: message),
        TransactionPortNoServersAvailable(:final network) =>
          TransactionReviewNoServersFailure(network: network),
      };
}
