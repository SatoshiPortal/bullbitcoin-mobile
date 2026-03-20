import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_order.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dlc_order_model.freezed.dart';
part 'dlc_order_model.g.dart';

@freezed
abstract class DlcOrderModel with _$DlcOrderModel {
  const factory DlcOrderModel({
    required String id,
    @JsonKey(name: 'option_type') required String optionType,
    required String side,
    required String status,
    @JsonKey(name: 'strike_price_sat') required int strikePriceSat,
    @JsonKey(name: 'premium_sat') required int premiumSat,
    required int quantity,
    @JsonKey(name: 'remaining_quantity') required int remainingQuantity,
    @JsonKey(name: 'expiry_timestamp') required int expiryTimestamp,
    @JsonKey(name: 'maker_pubkey') String? makerPubkey,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _DlcOrderModel;
  const DlcOrderModel._();

  factory DlcOrderModel.fromJson(Map<String, dynamic> json) =>
      _$DlcOrderModelFromJson(json);

  DlcOrder toEntity() => DlcOrder(
        id: id,
        optionType: optionType == 'call' ? DlcOptionType.call : DlcOptionType.put,
        side: side == 'buy' ? DlcOrderSide.buy : DlcOrderSide.sell,
        status: _parseStatus(status),
        strikePriceSat: strikePriceSat,
        premiumSat: premiumSat,
        quantity: quantity,
        remainingQuantity: remainingQuantity,
        expiryTimestamp: expiryTimestamp,
        makerPubkey: makerPubkey,
        createdAt: createdAt,
      );

  static DlcOrderStatus _parseStatus(String raw) => switch (raw) {
        'open' => DlcOrderStatus.open,
        'partially_filled' => DlcOrderStatus.partiallyFilled,
        'filled' => DlcOrderStatus.filled,
        'cancelled' => DlcOrderStatus.cancelled,
        'expired' => DlcOrderStatus.expired,
        _ => DlcOrderStatus.open,
      };
}
