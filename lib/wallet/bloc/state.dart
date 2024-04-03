import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lwk_dart/lwk_dart.dart' as lwk;

part 'state.freezed.dart';

@freezed
class WalletState with _$WalletState {
  const factory WalletState({
    Wallet? wallet,
    // bdk.Wallet? bdkWallet,
    // List<Transaction>? txs,
    // Balance? balance,
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
    @Default(0) int syncErrCount,
    // Address? newAddress,
    Address? firstAddress,
    required WalletCreate walletCreate,
  }) = _WalletState;
  const WalletState._();

  String balanceStr() => ((wallet?.balance ?? 0) / 100000000).toStringAsFixed(8);

  int balanceSats() => wallet?.balance ?? 0;

  bool loading() => syncing || loadingTxs || loadingBalance;

  (bdk.Wallet?, Err?) getBdkWallet() {
    if (wallet!.baseWalletType != BaseWalletType.Bitcoin) return (null, Err('Invalid Wallet Type'));
    return walletCreate.getBdkWallet(wallet!);
  }

  (lwk.Wallet?, Err?) getLwkWallet() {
    if (wallet!.baseWalletType != BaseWalletType.Liquid) return (null, Err('Invalid Wallet Type'));
    return walletCreate.getLwkWallet(wallet!);
  }
}
