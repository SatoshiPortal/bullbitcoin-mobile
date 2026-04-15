import 'package:bb_mobile/core/transactions/application/transaction_port.dart';
import 'package:bb_mobile/core/transactions/domain/entity/transaction.dart';
import 'package:bb_mobile/core/transactions/domain/entity/transaction_entity.dart';
import 'package:bb_mobile/core/transactions/domain/error/transaction_error.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_input.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';

/// Use case for building a [TransactionEntity] from either:
/// - An external [Transaction] (PSBT/HEX) — async, resolves input values
/// - A [WalletTransaction] (wallet-built) — sync, uses local data
class BuildTransactionUsecase {
  final TransactionPort _transactionPort;

  BuildTransactionUsecase({required TransactionPort transactionPort})
    : _transactionPort = transactionPort;

  /// Build from an external [Transaction] (parsed from PSBT or HEX).
  ///
  /// For each input, fetches the parent transaction via [TransactionPort]
  /// and looks up the output at the referenced vout to resolve the value.
  ///
  /// Change output index is always null for external transactions
  /// since we cannot determine which output is change.
  ///
  /// Throws [TransactionError] if any parent transaction cannot be fetched
  /// or if the referenced output index doesn't exist.
  Future<TransactionEntity> executeFromTransaction(Transaction tx) async {
    final resolvedInputs = <ResolvedInput>[];

    for (final input in tx.inputs) {
      try {
        final parentTx = await _transactionPort.fetch(txid: input.previousTxId);

        if (input.previousVout >= parentTx.outputs.length) {
          throw TransactionError.inputResolutionFailed(
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
      } on TransactionError {
        rethrow;
      } catch (e) {
        throw TransactionError.fetchFailed(
          txid: input.previousTxId,
          message: e.toString(),
        );
      }
    }

    return TransactionEntity(
      transaction: tx,
      resolvedInputs: resolvedInputs,
      // Change is unknown for external transactions
      changeOutputIndex: null,
    );
  }

  /// Build from a [WalletTransaction] (wallet-built transaction).
  ///
  /// Input values and change output are derived from the wallet's
  /// local data using the `isOwn` flag on outputs.
  ///
  /// This is synchronous since all data is already available.
  TransactionEntity executeFromWalletTransaction(
    WalletTransaction walletTx,
    Transaction tx,
  ) {
    // Resolve inputs from the wallet transaction data
    final resolvedInputs = walletTx.inputs.map((input) {
      final valueSat = switch (input) {
        BitcoinTransactionInput(:final value) => value?.toInt() ?? 0,
        LiquidTransactionInput(:final value) => value.toInt(),
      };
      return ResolvedInput(
        valueSat: valueSat,
        previousTxId: input.previousTxId,
        previousVout: input.previousTxVout,
      );
    }).toList();
    // Find the change output index using the isOwn flag.
    // For outgoing transactions, the change output is the one marked as own.
    // For incoming or to-self transactions, there is no meaningful "change".
    int? changeOutputIndex;
    if (walletTx.isOutgoing && !walletTx.isToSelf) {
      for (int i = 0; i < walletTx.outputs.length; i++) {
        if (walletTx.outputs[i].isOwn) {
          changeOutputIndex = i;
          break;
        }
      }
    }

    return TransactionEntity(
      transaction: tx,
      resolvedInputs: resolvedInputs,
      changeOutputIndex: changeOutputIndex,
    );
  }
}
