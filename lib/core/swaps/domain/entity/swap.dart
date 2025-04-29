import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
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
  final double? boltzPercent;
  final int? boltzFee;
  final int? lockupFee;
  final int? claimFee;

  const SwapFees({
    this.boltzPercent,
    this.boltzFee,
    this.lockupFee,
    this.claimFee,
  });

  int? totalFees(int? amount) {
    int total = 0;
    if (boltzFee != null) total += boltzFee!;
    if (boltzFee == null) {
      final boltzFee = boltzFeeFromPercent(amount ?? 0);
      total += boltzFee;
    }
    if (lockupFee != null) total += lockupFee!;
    if (claimFee != null) total += claimFee!;
    return total;
  }

  int boltzFeeFromPercent(int amount) {
    if (boltzPercent == null) {
      return 0;
    }
    return ((amount * boltzPercent!) / 100).ceil();
  }

  double boltzPercentFromFees(int amount) {
    if (boltzFee == null) {
      return 0;
    }

    return double.parse(((boltzFee! / amount) * 100).toStringAsFixed(2));
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
    required String paymentAddress,
    required int paymentAmount,
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

  String get abbreviatedReceiveTxid => switch (this) {
    final LnReceiveSwap swap => StringFormatting.truncateMiddle(
      swap.receiveTxid ?? '',
    ),
    final ChainSwap swap => StringFormatting.truncateMiddle(
      swap.receiveTxid ?? '',
    ),
    _ => '',
  };

  String get abbreviatedInvoice => switch (this) {
    final LnReceiveSwap swap => StringFormatting.truncateMiddle(swap.invoice),
    final LnSendSwap swap => StringFormatting.truncateMiddle(swap.invoice),
    _ => '',
  };

  @override
  String get id => switch (this) {
    LnReceiveSwap(:final id) => id,
    LnSendSwap(:final id) => id,
    ChainSwap(:final id) => id,
  };

  @override
  SwapType get type => switch (this) {
    LnReceiveSwap(:final type) => type,
    LnSendSwap(:final type) => type,
    ChainSwap(:final type) => type,
  };

  @override
  SwapStatus get status => switch (this) {
    LnReceiveSwap(:final status) => status,
    LnSendSwap(:final status) => status,
    ChainSwap(:final status) => status,
  };

  @override
  SwapFees? get fees => switch (this) {
    LnReceiveSwap(:final fees) => fees,
    LnSendSwap(:final fees) => fees,
    ChainSwap(:final fees) => fees,
  };
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
