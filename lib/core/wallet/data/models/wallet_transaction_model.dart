import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_transaction_model.freezed.dart';

@freezed
sealed class WalletTransactionModel with _$WalletTransactionModel {
  const factory WalletTransactionModel({
    required Network network,
    required String txId,
    required bool isIncoming,
    required int amount,
    required int fees,
    int? confirmationTimestamp,
  }) = _WalletTransactionModel;
  const WalletTransactionModel._();
}
