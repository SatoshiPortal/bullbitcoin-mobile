import 'dart:async';

import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_details_cubit.freezed.dart';
part 'transaction_details_state.dart';

class TransactionDetailsCubit extends Cubit<TransactionDetailsState> {
  TransactionDetailsCubit({
    //required GetPayjoinUsecase getPayjoinUsecase,
    required WatchPayjoinUsecase watchPayjoinUsecase,
  }) : //_getPayjoinUsecase = getPayjoinUsecase,
       _watchPayjoinUsecase = watchPayjoinUsecase,
       super(const TransactionDetailsState());

  //final GetPayjoinUsecase _getPayjoinUsecase;
  final WatchPayjoinUsecase _watchPayjoinUsecase;

  StreamSubscription? _payjoinSubscription;
  StreamSubscription? _swapSubscription;

  @override
  Future<void> close() async {
    await (
      _payjoinSubscription?.cancel() ?? Future.value(),
      _swapSubscription?.cancel() ?? Future.value(),
    ).wait;
    return super.close();
  }

  Future<void> loadTxDetails(WalletTransaction tx) async {
    try {
      emit(state.copyWith(transaction: tx));

      // Check if the transaction was a payjoin
      if (tx is BitcoinWalletTransaction) {
        final payjoinId = tx.payjoinId;
        if (payjoinId.isNotEmpty) {
          //final payjoin = await _getPayjoinUsecase.execute(payjoinId);
          _payjoinSubscription = _watchPayjoinUsecase
              .execute(ids: [payjoinId])
              .listen((payjoin) => emit(state.copyWith(payjoin: payjoin)));

          //emit(state.copyWith(payjoin: payjoin));
        }
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(err: e));
      }
    }
  }

  Future<void> loadPayjoinDetails(String payjoinId) async {
    try {
      //final payjoin = await _getPayjoinUsecase.execute(payjoinId);
      _payjoinSubscription = _watchPayjoinUsecase
          .execute(ids: [payjoinId])
          .listen((payjoin) => emit(state.copyWith(payjoin: payjoin)));

      //emit(state.copyWith(payjoin: payjoin));
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(err: e));
      }
    }
  }
}
