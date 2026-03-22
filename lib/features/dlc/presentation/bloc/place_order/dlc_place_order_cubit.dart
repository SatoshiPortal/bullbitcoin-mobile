import 'package:bb_mobile/core/dlc/data/datasources/dlc_wallet_token_store.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_order.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/place_dlc_order_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dlc_place_order_state.dart';
part 'dlc_place_order_cubit.freezed.dart';

class DlcPlaceOrderCubit extends Cubit<DlcPlaceOrderState> {
  DlcPlaceOrderCubit({
    required PlaceDlcOrderUsecase placeDlcOrderUsecase,
    required DlcWalletTokenStore tokenStore,
  })  : _placeDlcOrderUsecase = placeDlcOrderUsecase,
        _tokenStore = tokenStore,
        super(const DlcPlaceOrderState());

  final PlaceDlcOrderUsecase _placeDlcOrderUsecase;
  final DlcWalletTokenStore _tokenStore;

  void setInstrument(String instrumentId) =>
      emit(state.copyWith(instrumentId: instrumentId, submittedOrderResponse: null, error: null));

  void setSide(DlcOrderSide side) =>
      emit(state.copyWith(side: side, submittedOrderResponse: null, error: null));

  void setPrice(int sats) =>
      emit(state.copyWith(price: sats, error: null));

  void setQuantity(int qty) =>
      emit(state.copyWith(quantity: qty, error: null));

  Future<void> submit({String? idempotencyKey}) async {
    if (!state.isValid) return;

    final fundingPubkeyHex = _tokenStore.fundingPubkeyHex;
    if (fundingPubkeyHex == null) {
      emit(state.copyWith(
        isSubmitting: false,
        error: Exception('Wallet not registered. Please enable DLC Options first.'),
      ));
      return;
    }

    emit(state.copyWith(isSubmitting: true, error: null, submittedOrderResponse: null));
    try {
      final response = await _placeDlcOrderUsecase.execute(
        instrumentId: state.instrumentId!,
        side: state.side,
        quantity: state.quantity,
        price: state.price,
        fundingPubkeyHex: fundingPubkeyHex,
        idempotencyKey: idempotencyKey,
      );
      emit(state.copyWith(isSubmitting: false, submittedOrderResponse: response));
    } on Exception catch (e) {
      emit(state.copyWith(isSubmitting: false, error: e));
    }
  }

  void reset() => emit(const DlcPlaceOrderState());
}
