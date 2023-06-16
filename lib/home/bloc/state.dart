import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/wallet/bloc/wallet_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
class HomeState with _$HomeState {
  const factory HomeState({
    List<Wallet>? wallets,
    @Default(true) bool loadingWallets,
    @Default('') String errLoadingWallets,
    Wallet? selectedWallet,
    WalletCubit? selectedWalletCubit,
  }) = _HomeState;
  const HomeState._();

  bool hasWallets() => !loadingWallets && wallets != null && wallets!.isNotEmpty;

  List<Wallet> walletsFromNetwork(BBNetwork network) =>
      wallets?.where((wallet) => wallet.network == network).toList().reversed.toList() ?? [];
}
