import 'package:ark_wallet/ark_wallet.dart' as ark_wallet;
import 'package:bb_mobile/core_deprecated/ark/entities/ark_balance.dart';
import 'package:bb_mobile/core_deprecated/ark/entities/ark_wallet.dart';
import 'package:bb_mobile/core_deprecated/ark/errors.dart';
import 'package:bb_mobile/core_deprecated/settings/domain/settings_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

enum ArkReceiveMethod { offchain, boarding }

enum AddressType { ark, btc }

@freezed
sealed class ArkState with _$ArkState {
  const factory ArkState({
    ArkError? error,
    @Default(false) bool isLoading,
    @Default(BitcoinUnit.sats) BitcoinUnit preferredBitcoinUnit,
    @Default('CAD') String preferrredFiatCurrencyCode,
    @Default([]) List<String> fiatCurrencyCodes,
    @Default(0) double exchangeRate,

    // Transaction History and Balances
    ArkBalance? arkBalance,
    @Default([]) List<ark_wallet.Transaction> transactions,

    // Receive
    @Default(ArkReceiveMethod.offchain) ArkReceiveMethod receiveMethod,

    // Send
    ({String address, AddressType type})? sendAddress,
    int? amountSat,
    String? currencyCode,
    @Default('') String txid,

    // Settle & Redeem
    @Default(true) bool withRecoverableVtxos,
  }) = _ArkState;
  const ArkState._();

  List<String> get inputCurrencyCodes =>
      fiatCurrencyCodes + BitcoinUnit.values.map((e) => e.code).toList();

  bool get isFiatCurrencyInput => fiatCurrencyCodes.contains(currencyCode);

  String get equivalentCurrencyCode =>
      isFiatCurrencyInput
          ? preferredBitcoinUnit.code
          : preferrredFiatCurrencyCode;

  bool get hasBoardingTransaction =>
      transactions.any((tx) => tx is ark_wallet.Transaction_Boarding);

  bool get hasArkAddress =>
      sendAddress != null && ArkWalletEntity.isArkAddress(sendAddress!.address);

  Future<bool> get hasBtcAddress async =>
      sendAddress != null &&
      await ArkWalletEntity.isBtcAddress(sendAddress!.address);

  Future<bool> get hasValidAddress async =>
      hasArkAddress || await hasBtcAddress;

  int get totalBalance => arkBalance?.completeTotal ?? 0;

  // Backward compatibility getters
  int get confirmedBalance => arkBalance?.total ?? 0;
  //int get pendingBalance => arkBalance?.preconfirmed ?? 0;
}
