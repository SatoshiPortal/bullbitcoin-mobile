import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

/// Display facts from the host's durable funding journal, never signing bytes.
/// Only a trusted read can issue the feature's private Board review token.
final class ArkBoardPreparation {
  final String operationId;
  final String reviewBinding;
  final ArkAccountId account;
  final String sourceWalletId;
  final Fingerprint sourceParent;
  final int sourceGeneration;
  final Sats fundingAmount;
  final Sats minerFee;
  final Sats arkFee;
  final Sats net;
  final FeeRate feeRate;
  final String unsignedTxid;
  final int expiryHeight;
  final DateTime validUntil;
  final Uri chainSource;
  final int configGeneration;

  const ArkBoardPreparation({
    required this.operationId,
    required this.reviewBinding,
    required this.account,
    required this.sourceWalletId,
    required this.sourceParent,
    required this.sourceGeneration,
    required this.fundingAmount,
    required this.minerFee,
    required this.arkFee,
    required this.net,
    required this.feeRate,
    required this.unsignedTxid,
    required this.expiryHeight,
    required this.validUntil,
    required this.chainSource,
    required this.configGeneration,
  });

  Sats get sourceDebit => Sats(fundingAmount.value + minerFee.value);
}
