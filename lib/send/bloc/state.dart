import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/currency.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
class SendState with _$SendState {
  const factory SendState({
    @Default(0) int amount,
    @Default('') String address,
    @Default('') String note,
    // @Default(BTCUnit.btc) BTCUnit unit,
    //
    int? fees,
    List<int>? feesList,
    @Default(2) int selectedFeesOption,
    //
    @Default(false) bool loadingFees,
    @Default('') String errLoadingFees,
    @Default(false) bool scanningAddress,
    @Default('') String errScanningAddress,
    //
    @Default(false) bool showSendButton,
    @Default(false) bool sending,
    @Default('') String errSending,
    @Default(false) bool sent,
    @Default('') String psbt,
    Transaction? tx,
    @Default(false) bool downloadingFile,
    @Default('') String errDownloadingFile,
    @Default(false) bool downloaded,
    //
    @Default(false) bool enableRBF,
    @Default(false) bool sendAllCoin,
    @Default([]) List<Address> selectedAddresses,
    @Default('') String errAddresses,
    //
    @Default(false) bool signed,
    String? psbtSigned,
    int? psbtSignedFeeAmount,
    // @Default(false) bool signing,
    // @Default('') String errSigning,
    //
    Currency? selectedCurrency,
    List<Currency>? currencyList,
    @Default(false) bool isSats,
    @Default(false) bool fiatSelected,
    @Default(0) double fiatAmt,
  }) = _SendState;
  const SendState._();

  bool selectedAddressesHasEnoughCoins() {
    final totalSelected = selectedAddresses.fold<int>(
      0,
      (previousValue, element) => previousValue + element.calculateBalance(),
    );
    return totalSelected >= amount;
  }

  int calculateTotalSelected() {
    return selectedAddresses.fold<int>(
      0,
      (previousValue, element) => previousValue + element.calculateBalance(),
    );
  }

  int totalUTXOsSelected() {
    return selectedAddresses.fold<int>(
      0,
      (previousValue, element) => previousValue + (element.utxos ?? []).length,
    );
  }

  bool addressIsSelected(Address address) {
    return selectedAddresses.contains(address);
  }

  String feeButtonText() {
    var str = '';
    try {
      if (selectedFeesOption == 0) str = 'Fastest (' + feesList![0].toString();
      if (selectedFeesOption == 1) str = 'Fast (' + feesList![1].toString();
      if (selectedFeesOption == 2) str = 'Medium (' + feesList![2].toString();
      if (selectedFeesOption == 3) str = 'Slow (' + feesList![3].toString();

      if (selectedFeesOption == 4) str = 'Manual (' + fees.toString();
      return str + ' sat/vByte)';
    } catch (e) {
      return 'Select fee rate';
    }
  }

  String advancedOptionsButtonText() {
    if (selectedAddresses.isEmpty) return 'Advanced options';
    // if (selectedAddressesHasEnoughCoins())
    return 'Selected ${selectedAddresses.length} addresses';
    // else
    // return 'Selected ${selectedAddresses.length} addresses (not enough coins)';
  }

  List<Currency> updatedCurrencyList() {
    final list = [
      const Currency(name: 'btc', price: 0, shortName: 'BTC'),
      const Currency(name: 'sats', price: 0, shortName: 'sats'),
      ...currencyList ?? <Currency>[],
    ];

    return list;
  }
}
