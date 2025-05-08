import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
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
    Swap? swap,
    String? payjoinId,
    String? exchangeId,
  }) {
    return switch (walletTransactionModel) {
      BitcoinWalletTransactionModel() => WalletTransaction.bitcoin(
        walletId: walletId,
        direction:
            walletTransactionModel.isIncoming
                ? WalletTransactionDirection.incoming
                : WalletTransactionDirection.outgoing,
        status:
            walletTransactionModel.confirmationTimestamp == null
                ? WalletTransactionStatus.pending
                : WalletTransactionStatus.confirmed,
        txId: walletTransactionModel.txId,
        amountSat: walletTransactionModel.amountSat,
        feeSat: walletTransactionModel.feeSat,
        confirmationTime:
            walletTransactionModel.confirmationTimestamp != null
                ? DateTime.fromMillisecondsSinceEpoch(
                  walletTransactionModel.confirmationTimestamp! * 1000,
                )
                : null,
        isToSelf: walletTransactionModel.isToSelf,
        labels: labels ?? [],
        payjoinId: payjoinId ?? '',
        swap: swap,
        exchangeId: exchangeId ?? '',
        inputs: inputs,
        outputs: outputs,
      ),
      LiquidWalletTransactionModel() => WalletTransaction.liquid(
        walletId: walletId,
        direction:
            walletTransactionModel.isIncoming
                ? WalletTransactionDirection.incoming
                : WalletTransactionDirection.outgoing,
        status:
            walletTransactionModel.confirmationTimestamp == null
                ? WalletTransactionStatus.pending
                : WalletTransactionStatus.confirmed,
        txId: walletTransactionModel.txId,
        amountSat: walletTransactionModel.amountSat,
        feeSat: walletTransactionModel.feeSat,
        confirmationTime:
            walletTransactionModel.confirmationTimestamp != null
                ? DateTime.fromMillisecondsSinceEpoch(
                  walletTransactionModel.confirmationTimestamp! * 1000,
                )
                : null,
        isToSelf: walletTransactionModel.isToSelf,
        labels: labels ?? [],
        swap: swap,
        exchangeId: exchangeId ?? '',
        inputs: inputs,
        outputs: outputs,
      ),
    };
  }
}
