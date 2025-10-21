import 'package:ark_wallet/ark_wallet.dart' as ark_wallet;
import 'package:bb_mobile/core/ark/entities/ark_balance.dart';
import 'package:bb_mobile/core/ark/entities/ark_wallet.dart';
import 'package:bb_mobile/core/ark/errors.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

enum ArkReceiveMethod { offchain, boarding }

enum AddressType { ark, btc }

@freezed
sealed class ArkState with _$ArkState {
  const factory ArkState({
    ArkError? error,
    @Default(false) bool isLoading,

    // Transaction History and Balances
    ArkBalance? arkBalance,
    @Default([]) List<ark_wallet.Transaction> transactions,

    // Receive
    @Default(ArkReceiveMethod.offchain) ArkReceiveMethod receiveMethod,

    // Send
    @Default(0) double exchangeRate,
    @Default('CAD') String currencyCode,
    @Default([]) List<String> fiatCurrencyCodes,
    @Default((address: '', type: null))
    ({String address, AddressType? type}) sendAddress,
    @Default('') String txid,

    // Settle & Redeem
    @Default(true) bool withRecoverableVtxos,
  }) = _ArkState;
}

extension ArkStateX on ArkState {
  bool get hasBoardingTransaction =>
      transactions.any((tx) => tx is ark_wallet.Transaction_Boarding);

  bool get hasArkAddress => ArkWalletEntity.isArkAddress(sendAddress.address);

  Future<bool> get hasBtcAddress =>
      ArkWalletEntity.isBtcAddress(sendAddress.address);

  Future<bool> get hasValidAddress async =>
      hasArkAddress || await hasBtcAddress;

  int get totalBalance => arkBalance?.completeTotal ?? 0;

  // Backward compatibility getters
  int get confirmedBalance => arkBalance?.boarding.confirmed ?? 0;
  int get pendingBalance => arkBalance?.boarding.unconfirmed ?? 0;
}
