import 'package:freezed_annotation/freezed_annotation.dart';

part 'bitcoin_transaction_recipient_model.freezed.dart';

@freezed
sealed class BitcoinTransactionRecipientModel
    with _$BitcoinTransactionRecipientModel {
  const factory BitcoinTransactionRecipientModel.fixed({
    required String address,
    required int fixedAmountSat,
  }) = FixedBitcoinTransactionRecipientModel;

  const factory BitcoinTransactionRecipientModel.remainder({
    required String address,
  }) = RemainderBitcoinTransactionRecipientModel;

  const BitcoinTransactionRecipientModel._();

  int? get amountSat => switch (this) {
    FixedBitcoinTransactionRecipientModel(:final fixedAmountSat) =>
      fixedAmountSat,
    RemainderBitcoinTransactionRecipientModel() => null,
  };
}
