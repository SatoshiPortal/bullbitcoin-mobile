import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:transactions/src/domain/entities/wallet_transaction.dart';
import 'package:transactions/src/domain/transaction_settlement.dart';
import 'package:transactions/src/domain/usecases/read_transaction_payment_animations_usecase.dart';
import 'package:transactions/src/domain/usecases/watch_settlement_transaction_usecase.dart';

part 'transaction_status_cubit.freezed.dart';
part 'transaction_status_state.dart';

/// What the payment status view needs besides the displayed transaction: the
/// animation preference and the live settlement transaction.
///
/// The settlement is observed apart from the displayed transaction and keyed by
/// its target, so it survives the details cubit swapping its own watchers (the
/// swap-id load resolving to the wallet transaction cancels its swap watch):
/// the same target never resubscribes, a changed one replaces the subscription.
class TransactionStatusCubit extends Cubit<TransactionStatusState> {
  TransactionStatusCubit({
    required this._readAnimations,
    required this._watchSettlement,
  }) : super(const TransactionStatusState());

  final ReadTransactionPaymentAnimationsUsecase _readAnimations;
  final WatchSettlementTransactionUsecase _watchSettlement;

  StreamSubscription<WalletTransaction>? _subscription;
  int _generation = 0;

  Future<void> loadPreference() async {
    final enabled = await _readAnimations.execute();
    if (isClosed) return;
    emit(state.copyWith(animationsEnabled: enabled));
  }

  /// Observes [target]; null stops the observation.
  void observeSettlement(TransactionSettlementTarget? target) {
    if (isClosed || target == state.settlementTarget) return;
    final generation = ++_generation;
    unawaited(_subscription?.cancel());
    _subscription = null;
    emit(state.copyWith(settlementTarget: target, settlement: null));
    if (target == null) return;
    _subscription = _watchSettlement.execute(target).listen(
      (transaction) {
        if (isClosed || generation != _generation) return;
        emit(state.copyWith(settlement: transaction));
      },
      // A dead observation keeps the last known state; the next target
      // change or reopening the screen restarts it.
      onError: (_) {},
    );
  }

  @override
  Future<void> close() async {
    _generation++;
    await _subscription?.cancel();
    return super.close();
  }
}
