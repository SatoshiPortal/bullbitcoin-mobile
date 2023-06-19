// ignore_for_file: invalid_annotation_target

import 'package:bb_mobile/_model/currency.dart';
import 'package:bb_mobile/_model/electrum.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_state.freezed.dart';
part 'settings_state.g.dart';

@freezed
class SettingsState with _$SettingsState {
  const factory SettingsState({
    @Default(false) bool unitsInSats,
    @Default(false) bool notifications,
    @Default(false) bool privacyView,
    //
    Currency? currency,
    List<Currency>? currencyList,
    DateTime? lastUpdatedCurrency,
    @Default(false) bool loadingCurrency,
    @Default('') String errLoadingCurrency,
    //
    String? language,
    List<String>? languageList,
    @Default(false) bool loadingLanguage,
    @Default('') String errLoadingLanguage,
    //
    @Default(false) bool testnet,
    @JsonKey(
      includeFromJson: false,
      includeToJson: false,
    )
    bdk.Blockchain? blockchain,
    @Default(20) int reloadWalletTimer,
    @Default([]) List<ElectrumNetwork> networks,
    @Default(0) int selectedNetwork,
    @Default(false) bool loadingNetworks,
    @Default('') String errLoadingNetworks,
    //
    int? fees,
    List<int>? feesList,
    @Default(2) int selectedFeesOption,
    //
    @Default(false) bool loadingFees,
    @Default('') String errLoadingFees,
    //
  }) = _SettingsState;
  const SettingsState._();

  factory SettingsState.fromJson(Map<String, dynamic> json) =>
      _$SettingsStateFromJson(json);

  ElectrumNetwork? getNetwork() {
    if (networks.isEmpty) return null;
    return networks[selectedNetwork];
  }

  String getAmountInUnits(
    int amount, {
    bool removeText = false,
    bool hideZero = false,
    bool removeEndZeros = false,
  }) {
    String amt = '';
    if (unitsInSats)
      amt = amount.toString() + ' sats';
    else {
      String b = '';
      if (!removeEndZeros)
        b = (amount / 100000000).toStringAsFixed(8);
      else
        b = (amount / 100000000).toStringAsFixed(8);
      amt = b + ' BTC';
    }

    if (removeText) {
      amt = amt.replaceAll(' sats', '');
      amt = amt.replaceAll(' BTC', '');
    }

    if (hideZero && amount == 0) amt = '';

    amt.replaceAll('-', '');

    return amt;
  }

  String calculatePrice(int sats) {
    if (currency == null) return '';
    if (testnet) return currency!.getSymbol() + '0';
    return currency!.getSymbol() +
        (sats / 100000000 * currency!.price!).toStringAsFixed(2);
  }

  String getUnitString() {
    if (unitsInSats) return 'sats';
    return 'BTC';
  }

  int getSatsAmount(String amount) {
    try {
      if (unitsInSats) return int.parse(amount);
      return (double.parse(amount) * 100000000).toInt();
    } catch (e) {
      debugPrint(e.toString());
      return 0;
    }
  }

  bdk.Network getBdkNetwork() {
    if (testnet) return bdk.Network.Testnet;
    return bdk.Network.Bitcoin;
  }

  BBNetwork getBBNetwork() {
    if (testnet) return BBNetwork.Testnet;
    return BBNetwork.Mainnet;
  }

  String explorerTxUrl(String txid) => testnet
      ? 'https://$mempoolapi/testnet/tx/$txid'
      : 'https://$mempoolapi/tx/$txid';

  String explorerAddressUrl(String address) => testnet
      ? 'https://$mempoolapi/testnet/address/$address'
      : 'https://$mempoolapi/address/$address';

  String feeButtonText() {
    var str = '';
    try {
      if (selectedFeesOption == 0)
        str = 'Fastest fee rate: ' + feesList![0].toString();
      if (selectedFeesOption == 1)
        str = 'Fast fee rate: ' + feesList![1].toString();
      if (selectedFeesOption == 2)
        str = 'Medium fee rate: ' + feesList![2].toString();
      if (selectedFeesOption == 3)
        str = 'Slow fee rate: ' + feesList![3].toString();

      if (selectedFeesOption == 4) str = 'Manual fee rate: ' + fees.toString();
      return str + ' sat/vByte';
    } catch (e) {
      return 'Select fee rate';
    }
  }
}

extension StringRegEx on String {
  String removeTrailingZero() {
    if (!contains('.')) {
      return this;
    }

    final String trimmed = replaceAll(RegExp(r'0*$'), '');
    if (!trimmed.endsWith('.')) {
      return trimmed;
    }
    try {
      return trimmed.substring(0, length - 1);
    } catch (e) {
      return trimmed;
    }
  }
}
