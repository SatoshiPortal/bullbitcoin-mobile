import 'package:bb_mobile/_model/address.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

enum ReceiveStep {
  defaultAddress,
  createInvoice,
  enterPrivateLabel,
  showInvoice,
}

@freezed
class ReceiveState with _$ReceiveState {
  const factory ReceiveState({
    @Default(ReceiveStep.defaultAddress) ReceiveStep step,
    // required bdk.Wallet bdkWallet,
    //
    Address? defaultAddress,
    // @Default('') String label,
    @Default(true) bool loadingAddress,
    @Default('') String errLoadingAddress,
    @Default(false) bool savingLabel,
    @Default('') String errSavingLabel,
    @Default(false) bool labelSaved,

    //
    @Default(0) int invoiceAmount,
    @Default('') String description,
    @Default('') String privateLabel,
    @Default('') String invoiceAddress,
    Address? newInvoiceAddress,
    @Default('') String errCreatingInvoice,
    @Default(true) bool creatingInvoice,
  }) = _ReceiveState;
  const ReceiveState._();
}
