import 'package:freezed_annotation/freezed_annotation.dart';

part 'dlc_contract.freezed.dart';

enum DlcOptionType { call, put }

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
    required DlcOptionType optionType,
    required DlcContractStatus status,
    /// Strike price in satoshis (BTC/USD rate represented as sats)
    required int strikePriceSat,
    /// Premium paid/received in satoshis
    required int premiumSat,
    /// Collateral locked in the contract (satoshis)
    required int collateralSat,
    /// Expiry as Unix timestamp
    required int expiryTimestamp,
    /// The counterparty's public key (hex)
    required String counterpartyPubkey,
    /// Oracle public key used for attestation (hex)
    required String oraclePubkey,
    /// Funding TXID once on-chain
    String? fundingTxId,
    /// CET (Contract Execution Transaction) signatures
    String? cetSignature,
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
