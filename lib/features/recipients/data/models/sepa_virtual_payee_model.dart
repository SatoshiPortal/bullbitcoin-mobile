import 'package:bb_mobile/features/recipients/domain/entities/sepa_virtual_payee_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sepa_virtual_payee_model.freezed.dart';
part 'sepa_virtual_payee_model.g.dart';

/// The virtual payee part of a SEPA recipient in the API's v2 responses.
@freezed
sealed class SepaVirtualPayeeModel with _$SepaVirtualPayeeModel {
  const factory SepaVirtualPayeeModel({
    required String recipientId,
    String? virtualPayeeStatus,
  }) = _SepaVirtualPayeeModel;

  factory SepaVirtualPayeeModel.fromJson(Map<String, dynamic> json) =>
      _$SepaVirtualPayeeModelFromJson(json);

  const SepaVirtualPayeeModel._();

  SepaVirtualPayeeStatus get status =>
      sepaVirtualPayeeStatusFromApi(virtualPayeeStatus);
}

/// The API reports no status until a virtual payee exists, and `ACTIVE` once
/// it can receive payouts. Any other value means activation is in progress.
SepaVirtualPayeeStatus sepaVirtualPayeeStatusFromApi(String? value) =>
    switch (value?.toUpperCase()) {
      null => SepaVirtualPayeeStatus.absent,
      'ACTIVE' => SepaVirtualPayeeStatus.active,
      _ => SepaVirtualPayeeStatus.pending,
    };
