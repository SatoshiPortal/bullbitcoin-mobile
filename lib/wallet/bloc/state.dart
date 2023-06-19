import 'package:bb_mobile/_model/wallet.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
class WalletState with _$WalletState {
  const factory WalletState({
    Wallet? wallet,
    bdk.Wallet? bdkWallet,
    // List<Transaction>? txs,
    Balance? balance,
    @Default('') String name,
    @Default(true) bool loadingWallet,
    @Default('') String errLoadingWallet,
    @Default(false) bool loadingTxs,
    @Default('') String errLoadingTxs,
    @Default(false) bool loadingBalance,
    @Default('') String errLoadingBalance,
    @Default(false) bool syncing,
    @Default('') String errSyncing,
    @Default(false) bool syncingAddresses,
    @Default('') String errSyncingAddresses,
    @Default(false) bool savingName,
    @Default('') String errSavingName,
    String? firstAddress,
  }) = _WalletState;
  const WalletState._();

  String balanceStr() =>
      ((wallet?.balance ?? 0) / 100000000).toStringAsFixed(8);

  int balanceSats() => wallet?.balance ?? 0;
}
