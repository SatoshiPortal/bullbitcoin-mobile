import 'package:bb_mobile/core/wallet/data/models/transaction_input_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_input.dart';

class TransactionInputMapper {
  static TransactionInput toEntity(
    TransactionInputModel transactionInputModel, {
    List<String>? labels,
  }) {
    return TransactionInput(
      txId: transactionInputModel.txId,
      vin: transactionInputModel.vin,
      value: transactionInputModel.value,
      scriptSig: transactionInputModel.scriptSig,
      previousTxId: transactionInputModel.previousTxId,
      previousTxVout: transactionInputModel.previousTxVout,
      labels: labels ?? [],
    );
  }

  static TransactionInputModel fromEntity(
    TransactionInput transactionInput,
  ) {
    return TransactionInputModel(
      txId: transactionInput.txId,
      vin: transactionInput.vin,
      value: transactionInput.value,
      scriptSig: transactionInput.scriptSig,
      previousTxId: transactionInput.previousTxId,
      previousTxVout: transactionInput.previousTxVout,
    );
  }
}
