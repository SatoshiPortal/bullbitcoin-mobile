import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
class SendState with _$SendState {
  const factory SendState({
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
    @Default([]) List<UTXO> selectedUtxos,
    @Default('') String errAddresses,
    @Default(false) bool signed,
    String? psbtSigned,
    int? psbtSignedFeeAmount,
    WalletBloc? selectedWalletBloc,
  }) = _SendState;
  const SendState._();

  bool selectedAddressesHasEnoughCoins(int amount) {
    return calculateTotalSelected() >= amount;
  }

  int calculateTotalSelected() {
    return selectedUtxos.fold<int>(
      0,
      (previousValue, element) => previousValue + element.value,
    );
  }

  bool utxoIsSelected(UTXO utxo) => selectedUtxos.containsUtxo(utxo);

  String advancedOptionsButtonText() {
    if (selectedUtxos.isEmpty) return 'Advanced options';

    return 'Selected ${selectedUtxos.length} addresses';
  }
}
