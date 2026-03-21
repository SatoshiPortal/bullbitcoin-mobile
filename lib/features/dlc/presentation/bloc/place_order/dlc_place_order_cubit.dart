import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_order.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/place_dlc_order_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dlc_place_order_state.dart';
part 'dlc_place_order_cubit.freezed.dart';

class DlcPlaceOrderCubit extends Cubit<DlcPlaceOrderState> {
  DlcPlaceOrderCubit({required PlaceDlcOrderUsecase placeDlcOrderUsecase})
      : _placeDlcOrderUsecase = placeDlcOrderUsecase,
        super(const DlcPlaceOrderState());

  final PlaceDlcOrderUsecase _placeDlcOrderUsecase;

  void setOptionType(DlcOptionType type) =>
      emit(state.copyWith(optionType: type, submittedOrder: null, error: null));

  void setSide(DlcOrderSide side) =>
      emit(state.copyWith(side: side, submittedOrder: null, error: null));

  void setStrikePrice(int sats) =>
      emit(state.copyWith(strikePriceSat: sats, error: null));

  void setPremium(int sats) =>
      emit(state.copyWith(premiumSat: sats, error: null));

  void setQuantity(int qty) =>
      emit(state.copyWith(quantity: qty, error: null));

  void setExpiry(DateTime expiry) =>
      emit(state.copyWith(expiryTimestamp: expiry.millisecondsSinceEpoch ~/ 1000, error: null));

  Future<void> submit({
    required String makerPubkey,
    required String signedOfferHex,
  }) async {
    if (!state.isValid) return;
    emit(state.copyWith(isSubmitting: true, error: null, submittedOrder: null));
    try {
      final order = await _placeDlcOrderUsecase.execute(
        optionType: state.optionType,
        side: state.side,
        strikePriceSat: state.strikePriceSat,
        premiumSat: state.premiumSat,
        quantity: state.quantity,
        expiryTimestamp: state.expiryTimestamp,
        makerPubkey: makerPubkey,
        signedOfferHex: signedOfferHex,
      );
      emit(state.copyWith(isSubmitting: false, submittedOrder: order));
    } on Exception catch (e) {
      emit(state.copyWith(isSubmitting: false, error: e));
    }
  }

  void reset() => emit(const DlcPlaceOrderState());
}
