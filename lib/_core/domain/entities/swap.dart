import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'swap.freezed.dart';
part 'swap.g.dart';

// These types are different than the ones from Boltz to decouple the app from the Boltz API
// In case the Boltz API changes or Boltz starts using new swap technique instead of submarine swaps,
//  or in case we want to add another swaps provider than Boltz,
//  we should be able to do so without changing the domain layer and the rest of the app,
//  only the data layer would need changes.
enum SwapType {
  lightningToBitcoin,
  lightningToLiquid,
  liquidToLightning,
  bitcoinToLightning,
  liquidToBitcoin,
  bitcoinToLiquid,
}

enum NextSwapAction {
  wait,
  claim,
  coopSign,
  refund,
  close,
}

// TODO: add/change to statusses that make sense for the application (so not just the same Boltz swap states, unless it is a status we need in the app to manage or show)
enum SwapStatus {
  pending,
  paid,
  claimable,
  refundable,
  canCoop,
  completed,
  refunded,
  expired,
  failed,
}

// @freezed
// class NetworkFees with _$NetworkFees {
//   /// Represents a fee using an absolute integer value
//   const factory NetworkFees.absolute(int value) = Absolute;

//   /// Represents a fee using a relative double value
//   const factory NetworkFees.relative(double value) = Relative;
// }

@freezed
class Swap with _$Swap {
  const factory Swap({
    required String id,
    required int keyIndex, // keys used for swap at swap path
    required SwapType type,
    required SwapStatus status,
    required Environment environment,
    required DateTime creationTime,
    int? boltzFee,
    int? lockupFee,
    int? claimFee,
    ChainSwapDetails? chainSwapDetails,
    LnReceiveSwapDetails? receiveSwapDetails,
    LnSendSwapDetails? sendSwapDetails,
    DateTime? completionTime,
  }) = _Swap;
  const Swap._();
}

@freezed
class ChainSwapDetails with _$ChainSwapDetails {
  const factory ChainSwapDetails({
    required String sendWalletId,
    String? sendTxid,
    String? receiveWalletId,
    String? receiveTxid,
    String? receiveAddress,
    String? refundTxid,
    String? refundAddress,
  }) = _ChainSwapDetails;
  const ChainSwapDetails._();

  bool get toSelf => receiveWalletId == null && receiveAddress != null;

  factory ChainSwapDetails.fromJson(Map<String, dynamic> json) =>
      _$ChainSwapDetailsFromJson(json);
}

@freezed
class LnReceiveSwapDetails with _$LnReceiveSwapDetails {
  const factory LnReceiveSwapDetails({
    required String receiveWalletId,
    required String invoice,
    String? receiveTxid,
    String? receiveAddress,
  }) = _LnReceiveSwapDetails;
  const LnReceiveSwapDetails._();

  factory LnReceiveSwapDetails.fromJson(Map<String, dynamic> json) =>
      _$LnReceiveSwapDetailsFromJson(json);
}

@freezed
class LnSendSwapDetails with _$LnSendSwapDetails {
  const factory LnSendSwapDetails({
    required String sendWalletId,
    required String invoice,
    String? sendTxid,
    String? preimage,
    String? refundTxid,
    String? refundAddress,
  }) = _LnSendSwapDetails;
  const LnSendSwapDetails._();

  factory LnSendSwapDetails.fromJson(Map<String, dynamic> json) =>
      _$LnSendSwapDetailsFromJson(json);
}

@freezed
class SwapLimits with _$SwapLimits {
  const factory SwapLimits({
    required int min,
    required int max,
  }) = _SwapLimits;

  factory SwapLimits.fromJson(Map<String, dynamic> json) =>
      _$SwapLimitsFromJson(json);
}

// @freezed
// class LightningSwapFees with _$LightningSwapFees {
//   const factory LightningSwapFees({
//     required double percentage,
//     required int minerFees,
//   }) = _LightningSwapFees;

//   factory LightningSwapFees.fromJson(Map<String, dynamic> json) =>
//       _$LightningSwapFeesFromJson(json);
// }

// @freezed
// class ChainMinerFees with _$ChainMinerFees {
//   const factory ChainMinerFees({
//     required int lockup,
//     required int claim,
//   }) = _ChainMinerFees;

//   factory ChainMinerFees.fromJson(Map<String, dynamic> json) =>
//       _$ChainMinerFeesFromJson(json);
// }

// @freezed
// class ChainSwapFees with _$ChainSwapFees {
//   const factory ChainSwapFees({
//     required double percentage,
//     required ChainMinerFees minerFees,
//   }) = _ChainSwapFees;

//   factory ChainSwapFees.fromJson(Map<String, dynamic> json) =>
//       _$ChainSwapFeesFromJson(json);
// }
