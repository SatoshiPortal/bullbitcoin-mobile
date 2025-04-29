import 'package:bb_mobile/core/wallet/data/models/transaction_input_model.dart';
import 'package:bb_mobile/core/wallet/data/models/transaction_output_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_transaction_model.freezed.dart';

@freezed
sealed class WalletTransactionModel with _$WalletTransactionModel {
  const factory WalletTransactionModel.bitcoin({
    required String txId,
    required bool isIncoming,
    required int amountSat,
    required int feeSat,
    required List<TransactionInputModel> inputs,
    required List<TransactionOutputModel> outputs,
    int? confirmationTimestamp,
    @Default(false) bool isToSelf,
  }) = BitcoinWalletTransactionModel;
  const factory WalletTransactionModel.liquid({
    required String txId,
    required bool isIncoming,
    required int amountSat,
    required int feeSat,
    required List<TransactionInputModel> inputs,
    required List<TransactionOutputModel> outputs,
    int? confirmationTimestamp,
    @Default(false) bool isToSelf,
  }) = LiquidWalletTransactionModel;
  const WalletTransactionModel._();

  String get labelRef => txId;
}
