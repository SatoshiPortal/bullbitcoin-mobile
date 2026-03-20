import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dlc_contract_model.freezed.dart';
part 'dlc_contract_model.g.dart';

@freezed
abstract class DlcContractModel with _$DlcContractModel {
  const factory DlcContractModel({
    required String id,
    @JsonKey(name: 'option_type') required String optionType,
    required String status,
    @JsonKey(name: 'strike_price_sat') required int strikePriceSat,
    @JsonKey(name: 'premium_sat') required int premiumSat,
    @JsonKey(name: 'collateral_sat') required int collateralSat,
    @JsonKey(name: 'expiry_timestamp') required int expiryTimestamp,
    @JsonKey(name: 'counterparty_pubkey') required String counterpartyPubkey,
    @JsonKey(name: 'oracle_pubkey') required String oraclePubkey,
    @JsonKey(name: 'funding_txid') String? fundingTxId,
    @JsonKey(name: 'cet_signature') String? cetSignature,
    String? label,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _DlcContractModel;
  const DlcContractModel._();

  factory DlcContractModel.fromJson(Map<String, dynamic> json) =>
      _$DlcContractModelFromJson(json);

  DlcContract toEntity() => DlcContract(
        id: id,
        optionType: optionType == 'call' ? DlcOptionType.call : DlcOptionType.put,
        status: _parseStatus(status),
        strikePriceSat: strikePriceSat,
        premiumSat: premiumSat,
        collateralSat: collateralSat,
        expiryTimestamp: expiryTimestamp,
        counterpartyPubkey: counterpartyPubkey,
        oraclePubkey: oraclePubkey,
        fundingTxId: fundingTxId,
        cetSignature: cetSignature,
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
