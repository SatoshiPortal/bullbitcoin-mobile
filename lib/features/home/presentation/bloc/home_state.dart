part of 'home_bloc.dart';

@freezed
sealed class HomeState with _$HomeState {
  const factory HomeState.initial() = _Initial;
  const factory HomeState.success({
    required WalletCardViewModel liquidWalletCard,
    required WalletCardViewModel bitcoinWalletCard,
    //required List<Transaction> transactions,
    @Default(false) bool isSyncingTransactions,
  }) = _Success;
  const factory HomeState.failure({Object? error}) = _Failure;
}
