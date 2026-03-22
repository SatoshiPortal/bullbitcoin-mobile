import 'package:bb_mobile/core/dlc/domain/entities/dlc_order.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dlc_order_model.freezed.dart';
part 'dlc_order_model.g.dart';

@freezed
abstract class DlcOrderModel with _$DlcOrderModel {
  const factory DlcOrderModel({
    @JsonKey(name: 'order_id') required String id,
    @JsonKey(name: 'instrument_id') required String instrumentId,
    required String side,
    required int quantity,
    required int price,
    @Default('open') String status,
    @JsonKey(name: 'is_maker') @Default(false) bool isMaker,
    @JsonKey(name: 'sign_required') @Default(false) bool signRequired,
    @JsonKey(name: 'dlc_id') String? dlcId,
    @JsonKey(name: 'dlc_status') String? dlcStatus,
    @JsonKey(name: 'offer_object_hex') String? offerObjectHex,
    @JsonKey(name: 'created_at') @Default('') String createdAt,
  }) = _DlcOrderModel;
  const DlcOrderModel._();

  factory DlcOrderModel.fromJson(Map<String, dynamic> json) =>
      _$DlcOrderModelFromJson(json);

  DlcOrder toEntity() => DlcOrder(
        id: id,
        instrumentId: instrumentId,
        side: side == 'buy' ? DlcOrderSide.buy : DlcOrderSide.sell,
        quantity: quantity,
        price: price,
        status: status,
        isMaker: isMaker,
        signRequired: signRequired,
        dlcId: dlcId,
        dlcStatus: dlcStatus,
        offerObjectHex: offerObjectHex,
        createdAt: createdAt,
      );
}
