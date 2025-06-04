import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_detail_event.dart';
part 'wallet_detail_state.dart';
part 'wallet_detail_bloc.freezed.dart';

class WalletDetailBloc extends Bloc<WalletDetailEvent, WalletDetailState> {
  WalletDetailBloc({
    required String walletId,
    required GetWalletUsecase getWalletUsecase,
  }) : _walletId = walletId,
       _getWalletUsecase = getWalletUsecase,
       super(const WalletDetailState()) {
    on<WalletDetailStarted>(_onStarted);
  }

  final String _walletId;
  final GetWalletUsecase _getWalletUsecase;

  Future<void> _onStarted(
    WalletDetailStarted event,
    Emitter<WalletDetailState> emit,
  ) async {
    try {
      final wallet = await _getWalletUsecase.execute(_walletId);

      emit(state.copyWith(wallet: wallet));
    } catch (e) {
      emit(state.copyWith(error: e));
    }
  }
}
