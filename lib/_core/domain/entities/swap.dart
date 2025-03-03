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

// TODO: add/change to statusses that make sense for the application (so not just the same Boltz swap states, unless it is a status we need in the app to manage or show)
enum SwapStatus {
  pending,
  paid,
  completed,
  refunded,
  expired,
  failed,
}

@freezed
class Swap with _$Swap {
  const factory Swap({
    required String id,
    required int keyIndex, // keys used for swap at swap path
    required SwapType type,
    required SwapStatus status,
    required Environment environment,
    required DateTime creationTime,
    ChainSwap? chainSwapDetails,
    LnReceiveSwap? receiveSwapDetails,
    LnSendSwap? sendSwapDetails,
    DateTime? completionTime,
  }) = _Swap;
  const Swap._();
}

@freezed
class ChainSwap with _$ChainSwap {
  const factory ChainSwap({
    required bool toSelf,
    required String sendWalletId,
    String? sendTxid,
    String? receiveWalletId,
    String? receiveTxid,
    String? receiveAddress,
    String? refundTxid,
    String? refundAddress,
  }) = _ChainSwap;
  const ChainSwap._();

  factory ChainSwap.fromJson(Map<String, dynamic> json) =>
      _$ChainSwapFromJson(json);
}

@freezed
class LnReceiveSwap with _$LnReceiveSwap {
  const factory LnReceiveSwap({
    required String receiveWalletId,
    required String invoice,
    String? receiveTxid,
    String? receiveAddress,
  }) = _LnReceiveSwap;
  const LnReceiveSwap._();

  factory LnReceiveSwap.fromJson(Map<String, dynamic> json) =>
      _$LnReceiveSwapFromJson(json);
}

@freezed
class LnSendSwap with _$LnSendSwap {
  const factory LnSendSwap({
    required String sendWalletId,
    required String invoice,
    String? sendTxid,
    String? preimage,
    String? refundTxid,
    String? refundAddress,
  }) = _LnSendSwap;
  const LnSendSwap._();

  factory LnSendSwap.fromJson(Map<String, dynamic> json) =>
      _$LnSendSwapFromJson(json);
}
