import 'package:freezed_annotation/freezed_annotation.dart';

part 'dlc_order.freezed.dart';

enum DlcOrderSide { buy, sell }

enum DlcOrderStatus {
  open,
  partiallyFilled,
  filled,
  cancelled,
  expired,
}

@freezed
abstract class DlcOrder with _$DlcOrder {
  const factory DlcOrder({
    required String id,
    required DlcOptionType optionType,
    required DlcOrderSide side,
    required DlcOrderStatus status,
    /// Strike price in satoshis
    required int strikePriceSat,
    /// Premium per contract in satoshis
    required int premiumSat,
    /// Total quantity (number of contracts)
    required int quantity,
    /// Remaining quantity not yet matched
    required int remainingQuantity,
    /// Contract expiry as Unix timestamp
    required int expiryTimestamp,
    /// Maker's public key (hex) — null if this is our own order from the book
    String? makerPubkey,
    /// ISO 8601 creation timestamp
    required String createdAt,
  }) = _DlcOrder;
  const DlcOrder._();

  bool get isOurs => makerPubkey == null;
  bool get isOpen => status == DlcOrderStatus.open || status == DlcOrderStatus.partiallyFilled;
}

// Re-export so consumers only need to import this file
export 'dlc_contract.dart' show DlcOptionType;
