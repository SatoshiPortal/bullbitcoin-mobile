import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'swap.freezed.dart';

// These types are different than the ones from Boltz to decouple the app from the Boltz API
enum SwapType {
  lightningToBitcoin,
  lightningToLiquid,
  liquidToLightning,
  bitcoinToLightning,
  liquidToBitcoin,
  bitcoinToLiquid,
}

enum SwapStatus {
  pending,
  paid,
  claimable,
  refundable,
  canCoop,
  completed,
  expired,
  failed,
}

@freezed
sealed class Swap with _$Swap {
  // Lightning Receive Swap (reverse swap)
  const factory Swap.lnReceive({
    required String id,
    required int keyIndex,
    required SwapType type,
    required SwapStatus status,
    required Environment environment,
    required DateTime creationTime,
    required String receiveWalletId,
    required String invoice,
    String? receiveAddress,
    String? receiveTxid,
    int? boltzFee,
    int? lockupFee,
    int? claimFee,
    DateTime? completionTime,
  }) = LnReceiveSwap;

  // Lightning Send Swap (submarine swap)
  const factory Swap.lnSend({
    required String id,
    required int keyIndex,
    required SwapType type,
    required SwapStatus status,
    required Environment environment,
    required DateTime creationTime,
    required String sendWalletId,
    required String invoice,
    String? sendTxid,
    String? preimage,
    String? refundAddress,
    String? refundTxid,
    int? boltzFee,
    int? lockupFee,
    int? claimFee,
    DateTime? completionTime,
  }) = LnSendSwap;

  // Chain Swap (between BTC and L-BTC)
  const factory Swap.chain({
    required String id,
    required int keyIndex,
    required SwapType type,
    required SwapStatus status,
    required Environment environment,
    required DateTime creationTime,
    required String sendWalletId,
    String? sendTxid,
    String? receiveWalletId,
    String? receiveAddress,
    String? receiveTxid,
    String? refundAddress,
    String? refundTxid,
    int? boltzFee,
    int? lockupFee,
    int? claimFee,
    DateTime? completionTime,
  }) = ChainSwap;

  const Swap._();

  // These getters can still be used across all types
  bool get isLnReceiveSwap => this is LnReceiveSwap;
  bool get isLnSendSwap => this is LnSendSwap;
  bool get isChainSwap => this is ChainSwap;

  // Helper to get the common fields regardless of type
  @override
  String get id => when(
        lnReceive: (
          id,
          _,
          __,
          ___,
          ____,
          _____,
          ______,
          _______,
          ________,
          _________,
          __________,
          ___________,
          ____________,
          _____________,
        ) =>
            id,
        lnSend: (
          id,
          _,
          __,
          ___,
          ____,
          _____,
          ______,
          _______,
          ________,
          _________,
          __________,
          ___________,
          ____________,
          _____________,
          ______________,
          _______________,
        ) =>
            id,
        chain: (
          id,
          _,
          __,
          ___,
          ____,
          _____,
          ______,
          _______,
          ________,
          _________,
          __________,
          ___________,
          ____________,
          _____________,
          ______________,
          _______________,
          ________________,
        ) =>
            id,
      );

  @override
  SwapType get type => when(
        lnReceive: (
          _,
          __,
          type,
          ___,
          ____,
          _____,
          ______,
          _______,
          ________,
          _________,
          __________,
          ___________,
          ____________,
          _____________,
        ) =>
            type,
        lnSend: (
          _,
          __,
          type,
          ___,
          ____,
          _____,
          ______,
          _______,
          ________,
          _________,
          __________,
          ___________,
          ____________,
          _____________,
          ______________,
          _______________,
        ) =>
            type,
        chain: (
          _,
          __,
          type,
          ___,
          ____,
          _____,
          ______,
          _______,
          ________,
          _________,
          __________,
          ___________,
          ____________,
          _____________,
          ______________,
          _______________,
          ________________,
        ) =>
            type,
      );

  @override
  SwapStatus get status => when(
        lnReceive: (
          _,
          __,
          ___,
          status,
          ____,
          _____,
          ______,
          _______,
          ________,
          _________,
          __________,
          ___________,
          ____________,
          _____________,
        ) =>
            status,
        lnSend: (
          _,
          __,
          ___,
          status,
          ____,
          _____,
          ______,
          _______,
          ________,
          _________,
          __________,
          ___________,
          ____________,
          _____________,
          ______________,
          _______________,
        ) =>
            status,
        chain: (
          _,
          __,
          ___,
          status,
          ____,
          _____,
          ______,
          _______,
          ________,
          _________,
          __________,
          ___________,
          ____________,
          _____________,
          ______________,
          _______________,
          ________________,
        ) =>
            status,
      );
}

class SwapLimits {
  final int min;
  final int max;

  const SwapLimits({required this.min, required this.max});
}

class Invoice {
  final int sats;
  final bool isExpired;
  final String? magicBip21;

  const Invoice({
    required this.sats,
    required this.isExpired,
    this.magicBip21,
  });
}
