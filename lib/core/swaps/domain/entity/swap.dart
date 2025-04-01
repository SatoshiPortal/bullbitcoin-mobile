import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'swap.freezed.dart';

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

class SwapFees {
  final int? boltzFee;
  final int? lockupFee;
  final int? claimFee;

  const SwapFees({
    this.boltzFee,
    this.lockupFee,
    this.claimFee,
  });

  int? get totalFees {
    if (boltzFee == null && lockupFee == null && claimFee == null) {
      return null;
    }

    int total = 0;
    if (boltzFee != null) total += boltzFee!;
    if (lockupFee != null) total += lockupFee!;
    if (claimFee != null) total += claimFee!;
    return total;
  }
}

@freezed
sealed class Swap with _$Swap {
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
    SwapFees? fees,
    DateTime? completionTime,
  }) = LnReceiveSwap;

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
    SwapFees? fees,
    DateTime? completionTime,
  }) = LnSendSwap;

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
    SwapFees? fees,
    DateTime? completionTime,
  }) = ChainSwap;

  const Swap._();

  bool get isLnReceiveSwap => this is LnReceiveSwap;
  bool get isLnSendSwap => this is LnSendSwap;
  bool get isChainSwap => this is ChainSwap;

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
        ) =>
            status,
      );

  @override
  SwapFees? get fees => when(
        lnReceive: (
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
          fees,
          ___________,
        ) =>
            fees,
        lnSend: (
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
          fees,
          _____________,
        ) =>
            fees,
        chain: (
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
          fees,
          ______________,
        ) =>
            fees,
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
  final String? description;

  const Invoice({
    required this.sats,
    required this.isExpired,
    this.magicBip21,
    this.description,
  });
}
