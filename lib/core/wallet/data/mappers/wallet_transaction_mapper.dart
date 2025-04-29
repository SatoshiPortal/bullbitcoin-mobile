import 'package:bb_mobile/core/wallet/data/models/wallet_transaction_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_input.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_output.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';

class WalletTransactionMapper {
  static WalletTransaction toEntity(
    WalletTransactionModel walletTransactionModel, {
    required String walletId,
    required List<TransactionInput> inputs,
    required List<TransactionOutput> outputs,
    List<String>? labels,
    String? swapId,
    String? payjoinId,
    String? exchangeId,
  }) {
    return walletTransactionModel.map(
      bitcoin: (model) => WalletTransaction.bitcoin(
        walletId: walletId,
        direction: model.isIncoming
            ? WalletTransactionDirection.incoming
            : WalletTransactionDirection.outgoing,
        status: model.confirmationTimestamp == null
            ? WalletTransactionStatus.pending
            : WalletTransactionStatus.confirmed,
        txId: model.txId,
        amountSat: model.amountSat,
        feeSat: model.feeSat,
        confirmationTime: model.confirmationTimestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(
                model.confirmationTimestamp! * 1000,
              )
            : null,
        isToSelf: model.isToSelf,
        labels: labels ?? [],
        payjoinId: payjoinId ?? '',
        swapId: swapId ?? '',
        exchangeId: exchangeId ?? '',
        inputs: inputs,
        outputs: outputs,
      ),
      liquid: (model) => WalletTransaction.liquid(
        walletId: walletId,
        direction: model.isIncoming
            ? WalletTransactionDirection.incoming
            : WalletTransactionDirection.outgoing,
        status: model.confirmationTimestamp == null
            ? WalletTransactionStatus.pending
            : WalletTransactionStatus.confirmed,
        txId: model.txId,
        amountSat: model.amountSat,
        feeSat: model.feeSat,
        confirmationTime: model.confirmationTimestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(
                model.confirmationTimestamp! * 1000,
              )
            : null,
        isToSelf: model.isToSelf,
        labels: labels ?? [],
        swapId: swapId ?? '',
        exchangeId: exchangeId ?? '',
        inputs: inputs,
        outputs: outputs,
      ),
    );
  }
}
