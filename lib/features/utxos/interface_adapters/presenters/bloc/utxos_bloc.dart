import 'package:bb_mobile/features/utxos/application/dto/requests/get_utxo_request.dart';
import 'package:bb_mobile/features/utxos/application/dto/requests/get_wallet_utxos_request.dart';
import 'package:bb_mobile/features/utxos/application/usecases/get_utxo_usecase.dart';
import 'package:bb_mobile/features/utxos/application/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/utxos/interface_adapters/presenters/view_models/utxo_view_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'utxos_bloc.freezed.dart';

part 'utxos_event.dart';
part 'utxos_state.dart';

class UtxosBloc extends Bloc<UtxosEvent, UtxosState> {
  final GetWalletUtxosUsecase _getWalletUtxosUsecase;
  final GetUtxoUsecase _getUtxoUsecase;

  UtxosBloc({
    required GetWalletUtxosUsecase getWalletUtxosUsecase,
    required GetUtxoUsecase getUtxoUsecase,
  }) : _getWalletUtxosUsecase = getWalletUtxosUsecase,
       _getUtxoUsecase = getUtxoUsecase,
       super(const UtxosState()) {
    on<UtxosLoaded>(_onLoaded);
    on<UtxosDetailLoaded>(_onDetailLoaded);
  }

  Future<void> _onLoaded(UtxosLoaded event, Emitter<UtxosState> emit) async {
    emit(const UtxosState(isLoading: true));
    try {
      final offset = event.offset ?? 0;
      final response = await _getWalletUtxosUsecase.execute(
        GetWalletUtxosRequest(
          walletId: event.walletId,
          limit: event.limit,
          offset: event.offset,
        ),
      );

      final newUtxos =
          response.utxos.map((dto) => UtxoViewModel.fromDto(dto)).toList();

      if (offset == 0) {
        emit(state.copyWith(utxos: newUtxos));
      } else {
        final updatedUtxos = List<UtxoViewModel>.from(state.utxos)
          ..addAll(newUtxos);
        emit(state.copyWith(utxos: updatedUtxos));
      }
    } catch (e) {
      emit(state.copyWith(exception: e as Exception));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onDetailLoaded(
    UtxosDetailLoaded event,
    Emitter<UtxosState> emit,
  ) async {
    emit(const UtxosState(isLoading: true));
    try {
      final response = await _getUtxoUsecase.execute(
        GetUtxoRequest(
          walletId: event.walletId,
          txId: event.txId,
          index: event.index,
        ),
      );

      final utxoViewModel = UtxoViewModel.fromDto(response.utxo);

      final updatedUtxos =
          List<UtxoViewModel>.from(state.utxos)
            ..removeWhere(
              (utxo) => utxo.txId == event.txId && utxo.index == event.index,
            )
            ..add(utxoViewModel);
      emit(state.copyWith(utxos: updatedUtxos));
    } catch (e) {
      emit(state.copyWith(exception: e as Exception));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }
}
