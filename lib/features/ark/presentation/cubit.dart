import 'package:bb_mobile/core/ark/entities/ark_wallet.dart';
import 'package:bb_mobile/core/ark/errors.dart';
import 'package:bb_mobile/features/ark/presentation/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ArkCubit extends Cubit<ArkState> {
  final ArkWallet wallet;

  ArkCubit({required this.wallet}) : super(const ArkState());

  void init() {
    loadBalance();
    loadTransactionsPerDay();
  }

  Future<void> loadTransactionsPerDay() async {
    try {
      final arkTransactions = await wallet.transactions;
      emit(state.copyWith(transactions: arkTransactions));
    } catch (e) {
      emit(state.copyWith(error: ArkError(e.toString())));
    }
  }

  Future<void> loadBalance() async {
    try {
      final balance = await wallet.balance;
      emit(
        state.copyWith(
          confirmedBalance: balance.confirmed,
          pendingBalance: balance.pending,
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: ArkError(e.toString())));
    }
  }

  void receiveMethodChanged(bool isOffchain) {
    final receiveMethod =
        isOffchain ? ArkReceiveMethod.offchain : ArkReceiveMethod.boarding;
    emit(state.copyWith(receiveMethod: receiveMethod));
  }
}
