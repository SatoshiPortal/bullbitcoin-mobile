import 'package:bb_mobile/core/utxo/domain/entities/utxo.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SendCubit extends Cubit<SendState> {
  SendCubit() : super(const SendState());

  void addressChanged(String address) {
    emit(state.copyWith(addressOrInvoice: address));
  }

  void sendTypeChanged(SendType sendType) {
    emit(state.copyWith(sendType: sendType));
  }

  void amountCurrencyChanged(String currency) {
    emit(state.copyWith(fiatCurrencyCode: currency));
  }

  void amountChanged(String amount) {
    emit(state.copyWith(amount: amount));
  }

  void maxAmountChanged() {
    // emit(state.copyWith(amount: state.wallet?.balance.toString() ?? ''));
  }

  void noteChanged(String note) {
    emit(state.copyWith(label: note));
  }

  void loadUtxos() {
    // emit(state.copyWith(utxos: utxos));
  }

  void utxoSelected(Utxo utxo) {
    final selectedUtxos = List.of(state.selectedUtxos);
    if (selectedUtxos.contains(utxo)) {
      selectedUtxos.remove(utxo);
    } else {
      selectedUtxos.add(utxo);
    }
    emit(state.copyWith(selectedUtxos: selectedUtxos));
  }

  void replaceByFeeChanged(bool replaceByFee) {
    emit(state.copyWith(replaceByFee: replaceByFee));
  }

  void loadFees() {
    // emit(state.copyWith(fees: fees));
  }

  void feesChanged(int feeRate) {
    // emit(state.copyWith(feeRate: feeRate));
  }

  void createTransaction() {
    // emit(state.copyWith(transaction: transaction));
  }

  void confirmTransaction() {
    // emit(state.copyWith(transaction: transaction));
  }
}
