import 'package:wallet/wallet.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction_input.dart';

class TransactionInputMapper {
  static TransactionInput toEntity(
    TransactionInputDetails transactionInputModel, {
    List<String>? labels,
  }) {
    switch (transactionInputModel) {
      case BitcoinTransactionInputDetails _:
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
      case LiquidTransactionInputDetails _:
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
}
