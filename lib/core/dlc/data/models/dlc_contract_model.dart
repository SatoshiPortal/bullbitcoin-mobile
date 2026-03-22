import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dlc_contract_model.freezed.dart';
part 'dlc_contract_model.g.dart';

@freezed
abstract class DlcContractModel with _$DlcContractModel {
  const factory DlcContractModel({
    @JsonKey(name: 'dlc_id') required String id,
    @JsonKey(name: 'order_id') @Default('') String orderId,
    required String status,
    @JsonKey(name: 'instrument_id') @Default('') String instrumentId,
    @Default(0) int price,
    @JsonKey(name: 'collateral_sat') @Default(0) int collateralSat,
    @JsonKey(name: 'funding_txid') String? fundingTxId,
    @JsonKey(name: 'cet_adaptor_signatures_hex') String? cetAdaptorSignaturesHex,
    @JsonKey(name: 'refund_signature_hex') String? refundSignatureHex,
    String? label,
    @JsonKey(name: 'created_at') @Default('') String createdAt,
  }) = _DlcContractModel;
  const DlcContractModel._();

  factory DlcContractModel.fromJson(Map<String, dynamic> json) =>
      _$DlcContractModelFromJson(json);

  DlcContract toEntity() => DlcContract(
        id: id,
        orderId: orderId,
        status: _parseStatus(status),
        instrumentId: instrumentId,
        price: price,
        collateralSat: collateralSat,
        fundingTxId: fundingTxId,
        cetAdaptorSignaturesHex: cetAdaptorSignaturesHex,
        refundSignatureHex: refundSignatureHex,
        label: label,
        createdAt: createdAt,
      );

  static DlcContractStatus _parseStatus(String raw) => switch (raw) {
        'offered' => DlcContractStatus.offered,
        'accepted' => DlcContractStatus.accepted,
        'signed' => DlcContractStatus.signed,
        'confirmed' => DlcContractStatus.confirmed,
        'closed' => DlcContractStatus.closed,
        'refunded' => DlcContractStatus.refunded,
        'rejected' => DlcContractStatus.rejected,
        _ => DlcContractStatus.offered,
      };
}
