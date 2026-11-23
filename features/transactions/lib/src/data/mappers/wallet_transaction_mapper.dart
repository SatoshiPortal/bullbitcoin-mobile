import 'package:transactions/src/data/mappers/transaction_input_mapper.dart';
import 'package:transactions/src/data/mappers/transaction_output_mapper.dart';
import 'package:transactions/src/data/models/wallet_transaction_model.dart';
import 'package:transactions/src/domain/entities/transaction_input.dart';
import 'package:transactions/src/domain/entities/transaction_output.dart';
import 'package:transactions/src/domain/entities/wallet_transaction.dart';
import 'package:labels/labels.dart';

class WalletTransactionMapper {
  static WalletTransactionModel fromEntity(
    WalletTransaction walletTransaction,
  ) {
    final confirmationTime = walletTransaction.confirmationTime;
    return WalletTransactionModel(
      txId: walletTransaction.txId,
      isIncoming:
          walletTransaction.direction == WalletTransactionDirection.incoming,
      amountSat: walletTransaction.amountSat,
      feeSat: walletTransaction.feeSat,
      inputs: walletTransaction.inputs
          .map((input) => TransactionInputMapper.fromEntity(input))
          .toList(),
      outputs: walletTransaction.outputs
          .map((output) => TransactionOutputMapper.fromEntity(output))
          .toList(),
      confirmationTimestamp: confirmationTime != null
          ? confirmationTime.millisecondsSinceEpoch ~/ 1000
          : null,
      isToSelf: walletTransaction.isToSelf,
      network: walletTransaction.network,
      unblindedUrl: walletTransaction.unblindedUrl,
      isRbf: walletTransaction.isRbf,
      vsize: walletTransaction.vsize,
    );
  }

  static WalletTransaction toEntity(
    WalletTransactionModel walletTransactionModel, {
    required String walletId,
    required List<TransactionInput> inputs,
    required List<TransactionOutput> outputs,
    List<Label>? labels,
    required bool isRbf,
  }) {
    return WalletTransaction(
      walletId: walletId,
      network: walletTransactionModel.network,
      direction: walletTransactionModel.isIncoming
          ? WalletTransactionDirection.incoming
          : WalletTransactionDirection.outgoing,
      status: walletTransactionModel.confirmationTimestamp == null
          ? WalletTransactionStatus.pending
          : WalletTransactionStatus.confirmed,
      txId: walletTransactionModel.txId,
      amountSat: walletTransactionModel.amountSat,
      feeSat: walletTransactionModel.feeSat,
      confirmationTime: walletTransactionModel.confirmationTimestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(
              walletTransactionModel.confirmationTimestamp! * 1000,
            )
          : null,
      isToSelf: walletTransactionModel.isToSelf,
      labels: labels ?? [],
      inputs: inputs,
      outputs: outputs,
      unblindedUrl: walletTransactionModel.unblindedUrl,
      isRbf: isRbf,
      vsize: walletTransactionModel.vsize,
    );
  }
}
