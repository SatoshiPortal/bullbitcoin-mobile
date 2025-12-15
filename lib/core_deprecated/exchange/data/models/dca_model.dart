import 'package:bb_mobile/core_deprecated/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/dca/domain/dca.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dca_model.freezed.dart';
part 'dca_model.g.dart';

@freezed
sealed class DcaModel with _$DcaModel {
  const factory DcaModel({
    required String userId,
    required int userNbr,
    required String amountStr,
    required String currencyCode,
    required String recurringFrequency,
    required String recipientType,
    required String nextRunAt,
    required String createdAt,
    required String address,
  }) = _DcaModel;
  const DcaModel._();

  factory DcaModel.fromJson(Map<String, dynamic> json) =>
      _$DcaModelFromJson(json);

  Dca toEntity() {
    return Dca(
      amount: double.parse(amountStr),
      currency: FiatCurrency.fromCode(currencyCode),
      frequency: switch (recurringFrequency) {
        'HOURLY' => DcaBuyFrequency.hourly,
        'DAILY' => DcaBuyFrequency.daily,
        'WEEKLY' => DcaBuyFrequency.weekly,
        'MONTHLY' => DcaBuyFrequency.monthly,
        _ => throw Exception('Unknown frequency: $recurringFrequency'),
      },
      network: switch (recipientType) {
        'OUT_BITCOIN_ADDRESS' => DcaNetwork.bitcoin,
        'OUT_LIGHTNING_ADDRESS' => DcaNetwork.lightning,
        'OUT_LIQUID_ADDRESS' => DcaNetwork.liquid,
        _ => throw Exception('Unknown network: $recipientType'),
      },
      address: address,
      nextPurchaseDate: DateTime.parse(nextRunAt),
    );
  }
}
