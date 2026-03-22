import 'package:bb_mobile/core/dlc/domain/entities/dlc_instrument.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dlc_instrument_model.freezed.dart';
part 'dlc_instrument_model.g.dart';

@freezed
abstract class DlcInstrumentModel with _$DlcInstrumentModel {
  const factory DlcInstrumentModel({
    @JsonKey(name: 'instrument_id') required String id,
    required String name,
    @Default('') String description,
    @JsonKey(name: 'option_type') @Default('call') String optionType,
    @JsonKey(name: 'strike_price_sat') @Default(0) int strikePriceSat,
    @JsonKey(name: 'expiry_timestamp') @Default(0) int expiryTimestamp,
    @Default('active') String status,
  }) = _DlcInstrumentModel;
  const DlcInstrumentModel._();

  factory DlcInstrumentModel.fromJson(Map<String, dynamic> json) =>
      _$DlcInstrumentModelFromJson(json);

  DlcInstrument toEntity() => DlcInstrument(
        id: id,
        name: name,
        description: description,
        optionType: optionType,
        strikePriceSat: strikePriceSat,
        expiryTimestamp: expiryTimestamp,
        status: status,
      );
}
