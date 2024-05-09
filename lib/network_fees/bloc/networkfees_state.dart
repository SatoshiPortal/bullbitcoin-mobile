import 'package:bb_mobile/_model/currency.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'networkfees_state.freezed.dart';
part 'networkfees_state.g.dart';

@freezed
class NetworkFeesState with _$NetworkFeesState {
  const factory NetworkFeesState({
    int? fees,
    List<int>? feesList,
    @Default(2) int selectedFeesOption,
    int? tempFees,
    int? tempSelectedFeesOption,
    @Default(false) bool feesSaved,
    @Default(false) bool loadingFees,
    @Default('') String errLoadingFees,
  }) = _NetworkFeesState;
  const NetworkFeesState._();

  factory NetworkFeesState.fromJson(Map<String, dynamic> json) =>
      _$NetworkFeesStateFromJson(json);

  String feeButtonText() {
    var str = '';
    try {
      final selectedOption = feeOption();

      if (selectedOption == 0)
        str = 'Fastest fee rate: ' + feesList![0].toString();
      if (selectedOption == 1)
        str = 'Fast fee rate: ' + feesList![1].toString();
      if (selectedOption == 2)
        str = 'Medium fee rate: ' + feesList![2].toString();
      if (selectedOption == 3)
        str = 'Slow fee rate: ' + feesList![3].toString();

      if (selectedFeesOption == 4) str = 'Manual fee rate: ' + fees.toString();
      return str + ' sat/vByte';
    } catch (e) {
      return 'Select fee rate';
    }
  }

  String feeSendButtonText() {
    var str = '';
    try {
      final selectedOption = feeOption();
      if (selectedOption == 0) str = 'Fastest (' + feesList![0].toString();
      if (selectedOption == 1) str = 'Fast (' + feesList![1].toString();
      if (selectedOption == 2) str = 'Medium (' + feesList![2].toString();
      if (selectedOption == 3) str = 'Slow (' + feesList![3].toString();

      if (selectedOption == 4) str = 'Manual (' + fees.toString();
      return str + ' sat/vByte)';
    } catch (e) {
      return 'Select fee rate';
    }
  }

  int selectedOrFirst(bool selectFirst) => feesList == null
      ? 0
      : selectFirst
          ? feesList![0]
          : selectedFeesOption == 4
              ? (fees ?? 0)
              : feesList![selectedFeesOption];

  String defaultFeeStatus() {
    try {
      var str = '';
      final selectedOption = feeOption();
      if (selectedOption == 0) str = feesList![0].toString();
      if (selectedOption == 1) str = feesList![1].toString();
      if (selectedOption == 2) str = feesList![2].toString();
      if (selectedOption == 3) str = feesList![3].toString();
      if (selectedOption == 4) str = fees.toString();

      return str + ' sats/vbyte';
    } catch (e) {
      return '';
    }
  }

  int feesForBump() {
    final isManualFees = feeOption() == 4;
    int fees = 0;
    if (!isManualFees)
      fees = feesList?[feeOption()] ?? 0;
    else
      fees = fee();

    return fees;
  }

  String calculateFiatPriceForFees({
    required int feeRate,
    required bool isTestnet,
    Currency? selectedCurrency,
  }) {
    if (selectedCurrency == null || selectedCurrency.price == null) return '';
    if (isTestnet) return '~ 0 ${selectedCurrency.shortName}';

    final btcAmt = (140 * feeRate) / 100000000;
    final amt = (btcAmt * selectedCurrency.price!).toStringAsFixed(2);

    final currencyStr = selectedCurrency.shortName;
    return '~ $amt $currencyStr';
  }

  int feeOption() => tempSelectedFeesOption ?? selectedFeesOption;
  int fee() => tempFees ?? fees ?? 0;
}
