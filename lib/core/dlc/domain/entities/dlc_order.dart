import 'package:freezed_annotation/freezed_annotation.dart';

part 'dlc_order.freezed.dart';

enum DlcOrderSide { buy, sell }

@freezed
abstract class DlcOrder with _$DlcOrder {
  const factory DlcOrder({
    required String id,
    required String instrumentId,
    required DlcOrderSide side,
    required int quantity,
    /// Price in satoshis
    required int price,
    required String status,
    /// True when this order belongs to the authenticated user and they are the maker
    @Default(false) bool isMaker,
    /// True when the maker must sign CETs to complete the DLC
    @Default(false) bool signRequired,
    /// Associated DLC id (set when order is matched)
    String? dlcId,
    /// Status of the associated DLC contract
    String? dlcStatus,
    /// Offer object hex (set when this is a maker order awaiting match)
    String? offerObjectHex,
    /// ISO 8601 creation timestamp
    required String createdAt,
  }) = _DlcOrder;
  const DlcOrder._();

  bool get isOpen => status == 'open';
  bool get isPendingMatchAccept => status == 'pending_match_accept';
  bool get isMatched => status == 'matched';
  bool get isCancelled => status == 'cancelled';
  bool get needsSignature => isMaker && signRequired;
}
