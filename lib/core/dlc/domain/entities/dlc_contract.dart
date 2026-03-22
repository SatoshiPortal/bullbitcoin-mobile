import 'package:freezed_annotation/freezed_annotation.dart';

part 'dlc_contract.freezed.dart';

enum DlcContractStatus {
  offered,
  accepted,
  signed,
  confirmed,
  closed,
  refunded,
  rejected,
}

@freezed
abstract class DlcContract with _$DlcContract {
  const factory DlcContract({
    required String id,
    required String orderId,
    required DlcContractStatus status,
    required String instrumentId,
    /// Price in satoshis
    @Default(0) int price,
    /// Collateral locked in the contract (satoshis)
    @Default(0) int collateralSat,
    /// Funding TXID once on-chain
    String? fundingTxId,
    /// CET (Contract Execution Transaction) adaptor signatures
    String? cetAdaptorSignaturesHex,
    /// Refund signature
    String? refundSignatureHex,
    /// Human-readable label
    String? label,
    /// ISO 8601 creation timestamp
    required String createdAt,
  }) = _DlcContract;
  const DlcContract._();

  bool get isActive =>
      status == DlcContractStatus.confirmed ||
      status == DlcContractStatus.signed ||
      status == DlcContractStatus.accepted;

  bool get isClosed =>
      status == DlcContractStatus.closed ||
      status == DlcContractStatus.refunded ||
      status == DlcContractStatus.rejected;
}
