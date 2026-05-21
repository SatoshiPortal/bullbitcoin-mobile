import 'package:bb_mobile/core/transactions/adapters/transaction_mapper.dart';
import 'package:bb_mobile/core/transactions/domain/domain_errors.dart';
import 'package:bb_mobile/core/transactions/domain/transaction_port.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart' as btc_utils;
import 'package:bb_mobile/features/broadcast_signed_tx/domain/domain_errors.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/reviewable_transaction.dart';

/// Build a [ReviewableTransaction] from a parsed [btc_utils.BitcoinTx]
/// (PSBT/HEX-derived), resolving each input's value by fetching the parent
/// transaction via [TransactionPort].
///
/// Change output is left unresolved (`null`) since external transactions
/// don't carry wallet-side ownership data.
class BuildReviewableTransactionUsecase {
  final TransactionPort _transactionPort;

  BuildReviewableTransactionUsecase({required TransactionPort transactionPort})
    : _transactionPort = transactionPort;

  /// Throws [TransactionReviewError] on failure (port errors are wrapped at
  /// the boundary as `portFailure`).
  Future<ReviewableTransaction> execute(
    btc_utils.BitcoinTx bitcoinTx, {
    required bool isTestnet,
  }) async {
    final tx = TransactionMapper.fromBitcoinTx(bitcoinTx, isTestnet: isTestnet);
    final resolvedInputs = <ResolvedInput>[];

    for (final input in tx.inputs) {
      try {
        final parentTx = await _transactionPort.fetch(txid: input.previousTxId);

        if (input.previousVout >= parentTx.outputs.length) {
          throw TransactionReviewError.inputResolutionFailed(
            parentTxId: input.previousTxId,
            vout: input.previousVout,
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
      } on TransactionReviewError {
        rethrow;
      } on TransactionPortError catch (e) {
        throw TransactionReviewError.portFailure(portError: e);
      } catch (e) {
        throw TransactionReviewError.unexpected(e.toString());
      }
    }

    return ReviewableTransaction(
      transaction: tx,
      resolvedInputs: resolvedInputs,
    );
  }
}
