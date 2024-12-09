import 'package:bb_mobile/_pkg/payjoin.dart';
import 'package:bb_mobile/payjoin/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PayjoinCubit extends Cubit<PayjoinState> {
  PayjoinCubit() : super(const PayjoinState());

  final address = TextEditingController();
  final amount = TextEditingController();
  final form = GlobalKey<FormState>();

  void clearToast() => state.copyWith(toast: '');

  String? validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a number';
    }
    try {
      BigInt.from(int.parse(value));
    } catch (_) {
      return 'Invalid number';
    }
    return null;
  }

  Future<void> clickCreateInvoice() async {
    if (form.currentState!.validate() && !state.isAwaiting) {
      final sats = BigInt.from(int.parse(amount.text));
      final receiver = address.text;

      emit(state.copyWith(isAwaiting: true));
      final x = await PayJoin.initReceiver(sats, receiver);
      emit(state.copyWith(payjoinUri: x.$2, isAwaiting: false));
    }
  }
}
