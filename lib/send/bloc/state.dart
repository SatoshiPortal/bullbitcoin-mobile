import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/swap/bloc/swap_cubit.dart';
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
    required SwapCubit swapCubit,
  }) = _SendState;
  const SendState._();

  bool selectedAddressesHasEnoughCoins(int amount) {
    return calculateTotalSelected() >= amount;
  }

  bool isWatchOnly() => selectedWalletBloc?.state.wallet?.watchOnly() ?? false;

  bool isLnInvoice() => address.startsWith('ln') && !isWatchOnly();

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

  bool generatingSwap() => swapCubit.state.generatingSwapInv;

  bool loadingWithSwap() {
    return generatingSwap() || sending || downloadingFile;
  }

  String errWithSwap() {
    if (swapCubit.state.errCreatingInvoice.isNotEmpty) {
      return swapCubit.state.errCreatingInvoice;
    }
    if (errSending.isNotEmpty) {
      return errSending;
    }
    if (errDownloadingFile.isNotEmpty) {
      return errDownloadingFile;
    }
    return '';
  }
}
