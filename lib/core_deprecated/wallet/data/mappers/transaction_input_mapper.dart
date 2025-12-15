import 'package:bb_mobile/core_deprecated/wallet/data/models/transaction_input_model.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/transaction_input.dart';

class TransactionInputMapper {
  static TransactionInput toEntity(
    TransactionInputModel transactionInputModel, {
    List<String>? labels,
  }) {
    switch (transactionInputModel) {
      case BitcoinTransactionInputModel _:
        return TransactionInput.bitcoin(
          txId: transactionInputModel.txId,
          vin: transactionInputModel.vin,
          isOwn: transactionInputModel.isOwn,
          value: transactionInputModel.value,
          scriptSig: transactionInputModel.scriptSig,
          previousTxId: transactionInputModel.previousTxId,
          previousTxVout: transactionInputModel.previousTxVout,
          labels: labels ?? [],
        );
      case LiquidTransactionInputModel _:
        return TransactionInput.liquid(
          txId: transactionInputModel.txId,
          vin: transactionInputModel.vin,
          isOwn: transactionInputModel.isOwn,
          value: transactionInputModel.value,
          scriptPubkey: transactionInputModel.scriptPubkey,
          previousTxId: transactionInputModel.previousTxId,
          previousTxVout: transactionInputModel.previousTxVout,
          labels: labels ?? [],
        );
    }
  }

  static TransactionInputModel fromEntity(TransactionInput transactionInput) {
    switch (transactionInput) {
      case BitcoinTransactionInput _:
        return TransactionInputModel.bitcoin(
          txId: transactionInput.txId,
          vin: transactionInput.vin,
          isOwn: transactionInput.isOwn,
          value: transactionInput.value,
          scriptSig: transactionInput.scriptSig,
          previousTxId: transactionInput.previousTxId,
          previousTxVout: transactionInput.previousTxVout,
        );
      case LiquidTransactionInput _:
        return TransactionInputModel.liquid(
          txId: transactionInput.txId,
          vin: transactionInput.vin,
          isOwn: transactionInput.isOwn,
          value: transactionInput.value,
          scriptPubkey: transactionInput.scriptPubkey,
          previousTxId: transactionInput.previousTxId,
          previousTxVout: transactionInput.previousTxVout,
        );
    }
  }
}
