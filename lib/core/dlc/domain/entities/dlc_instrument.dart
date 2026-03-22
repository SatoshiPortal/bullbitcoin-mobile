import 'package:freezed_annotation/freezed_annotation.dart';

part 'dlc_instrument.freezed.dart';

@freezed
abstract class DlcInstrument with _$DlcInstrument {
  const factory DlcInstrument({
    required String id,
    required String name,
    required String description,
    /// Option type: call or put
    required String optionType,
    /// Strike price in satoshis
    required int strikePriceSat,
    /// Expiry as Unix timestamp
    required int expiryTimestamp,
    /// Instrument status (active, expired, etc.)
    required String status,
  }) = _DlcInstrument;
  const DlcInstrument._();

  bool get isActive => status == 'active';
  bool get isExpired => status == 'expired';
}
