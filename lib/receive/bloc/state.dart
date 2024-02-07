import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:boltz_dart/boltz_dart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

enum ReceiveWalletType { secure, lightning }

@freezed
class ReceiveState with _$ReceiveState {
  const factory ReceiveState({
    @Default(true) bool loadingAddress,
    @Default('') String errLoadingAddress,
    Address? defaultAddress,
    @Default('') String privateLabel,
    @Default(false) bool savingLabel,
    @Default('') String errSavingLabel,
    @Default(false) bool labelSaved,
    @Default(0) int savedInvoiceAmount,
    @Default('') String description,
    @Default('') String savedDescription,
    @Default(true) bool creatingInvoice,
    @Default('') String errCreatingInvoice,
    WalletBloc? walletBloc,
    @Default(ReceiveWalletType.secure) ReceiveWalletType walletType,
    @Default('') String errGeneratingInvoice,
    @Default(false) bool generatingInvoice,
    BtcLnSwap? btcLnSwap,
    // Address? newInvoiceAddress,
  }) = _ReceiveState;
  const ReceiveState._();

  String getQRStr() {
    if (defaultAddress == null) {
      if (btcLnSwap == null) return '';
      return btcLnSwap!.btcLnSwap.invoice;
    }

    if (savedInvoiceAmount > 0 || savedDescription.isNotEmpty) {
      final btcAmt = (savedInvoiceAmount / 100000000).toStringAsFixed(8);

      var invoice = 'bitcoin:' + defaultAddress!.address + '?amount=' + btcAmt;
      if (savedDescription.isNotEmpty) invoice = invoice + '&label=' + savedDescription;

      return invoice;
    }

    return defaultAddress!.address;
  }

  bool showNewRequestButton() => savedDescription.isEmpty && savedInvoiceAmount == 0;

  bool showQR() =>
      (btcLnSwap != null && walletType == ReceiveWalletType.lightning) ||
      (btcLnSwap == null && walletType == ReceiveWalletType.secure);
}
