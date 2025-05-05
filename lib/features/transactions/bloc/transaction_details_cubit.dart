import 'dart:async';

import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/get_payjoin_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_details_cubit.freezed.dart';
part 'transaction_details_state.dart';

class TransactionDetailsCubit extends Cubit<TransactionDetailsState> {
  TransactionDetailsCubit({
    required GetWalletUsecase getWalletUsecase,
    required GetSwapUsecase getSwapUsecase,
    required WatchSwapUsecase watchSwapUsecase,
    required GetPayjoinByIdUsecase getPayjoinByIdUsecase,
    required WatchPayjoinUsecase watchPayjoinUsecase,
  }) : _getWalletUsecase = getWalletUsecase,
       _getSwapUsecase = getSwapUsecase,
       _watchSwapUsecase = watchSwapUsecase,
       _getPayjoinByIdUsecase = getPayjoinByIdUsecase,
       _watchPayjoinUsecase = watchPayjoinUsecase,
       super(const TransactionDetailsState());

  final GetWalletUsecase _getWalletUsecase;
  final GetSwapUsecase _getSwapUsecase;
  final WatchSwapUsecase _watchSwapUsecase;
  final GetPayjoinByIdUsecase _getPayjoinByIdUsecase;
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

      // Load the wallet
      final wallet = await _getWalletUsecase.execute(tx.walletId);
      emit(state.copyWith(wallet: wallet));

      // Check if the transaction was a payjoin
      if (tx is BitcoinWalletTransaction) {
        final payjoinId = tx.payjoinId;
        if (payjoinId.isNotEmpty) {
          final payjoin = await _getPayjoinByIdUsecase.execute(payjoinId);
          _payjoinSubscription = _watchPayjoinUsecase
              .execute(ids: [payjoinId])
              .listen((payjoin) => emit(state.copyWith(payjoin: payjoin)));

          emit(state.copyWith(payjoin: payjoin));
        }
      }

      final swapId = tx.swapId;
      if (swapId.isNotEmpty) {
        // Get swap by id
        final swap = await _getSwapUsecase.execute(
          swapId,
          isTestnet: wallet.isTestnet,
        );
        // Watch swap by id so the UI can update if the state changes
        _swapSubscription = _watchSwapUsecase
            .execute(swapId)
            .listen((swap) => emit(state.copyWith(swap: swap)));
        emit(state.copyWith(swap: swap));
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(err: e));
      }
    }
  }

  Future<void> loadPayjoinDetails(String payjoinId) async {
    try {
      // Load the wallet
      final wallet = await _getWalletUsecase.execute(payjoinId);
      emit(state.copyWith(wallet: wallet));

      final payjoin = await _getPayjoinByIdUsecase.execute(payjoinId);
      _payjoinSubscription = _watchPayjoinUsecase
          .execute(ids: [payjoinId])
          .listen((payjoin) => emit(state.copyWith(payjoin: payjoin)));

      emit(state.copyWith(payjoin: payjoin));
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(err: e));
      }
    }
  }
}
