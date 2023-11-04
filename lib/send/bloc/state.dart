import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
class SendState with _$SendState {
  const factory SendState({
    String? tempAmount,
    @Default('') String address,
    @Default('') String note,
    @Default(false) bool scanningAddress,
    @Default('') String errScanningAddress,
    @Default(false) bool showSendButton,
    @Default(false) bool sending,
    @Default('') String errSending,
    @Default(false) bool sent,
    @Default('') String psbt,
    Transaction? tx,
    @Default(false) bool downloadingFile,
    @Default('') String errDownloadingFile,
    @Default(false) bool downloaded,
    @Default(false) bool disableRBF,
    @Default(false) bool sendAllCoin,
    @Default([]) List<Address> selectedAddresses,
    @Default('') String errAddresses,
    @Default(false) bool signed,
    String? psbtSigned,
    int? psbtSignedFeeAmount,
  }) = _SendState;
  const SendState._();

  bool selectedAddressesHasEnoughCoins(int amount) {
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

  String advancedOptionsButtonText() {
    if (selectedAddresses.isEmpty) return 'Advanced options';

    return 'Selected ${selectedAddresses.length} addresses';
  }
}
