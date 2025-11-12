import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/percentage.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bolt11_decoder/bolt11_decoder.dart';
import 'package:decimal/decimal.dart';
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

extension SwapTypeX on SwapType {
  bool get isReverse =>
      this == SwapType.lightningToBitcoin || this == SwapType.lightningToLiquid;

  bool get isSubmarine =>
      this == SwapType.bitcoinToLightning || this == SwapType.liquidToLightning;

  bool get isChain =>
      this == SwapType.bitcoinToLiquid || this == SwapType.liquidToBitcoin;
}

enum SwapStatus {
  pending,
  paid,
  claimable,
  refundable,
  canCoop,
  completed,
  expired,
  failed;

  String get displayName {
    switch (this) {
      case SwapStatus.pending:
        return 'Pending';
      case SwapStatus.paid:
      case SwapStatus.claimable:
      case SwapStatus.refundable:
      case SwapStatus.canCoop:
        return 'In Progress';
      case SwapStatus.completed:
        return 'Completed';
      case SwapStatus.expired:
        return 'Expired';
      case SwapStatus.failed:
        return 'Failed';
    }
  }
}

@freezed
abstract class SwapFees with _$SwapFees {
  const factory SwapFees({
    double? boltzPercent,
    int? boltzFee,
    int? lockupFee,
    int? claimFee,
    int? serverNetworkFees,
  }) = _SwapFees;

  const SwapFees._();

  int totalFees(int? amount) {
    int total = 0;
    // Always use percentage-based calculation for Boltz fees to ensure proper rounding
    if (boltzPercent != null) {
      final boltzFee = boltzFeeFromPercent(amount ?? 0);
      total += boltzFee;
    } else if (boltzFee != null) {
      total += boltzFee!;
    }
    if (lockupFee != null) total += lockupFee!;
    if (claimFee != null) total += claimFee!;
    if (serverNetworkFees != null) total += serverNetworkFees!;
    return total;
  }

  int totalFeesMinusLockup(int? amount) {
    return totalFees(amount) - (lockupFee ?? 0);
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

  double totalFeeAsPercentOfAmount(int amount) {
    final fees = totalFees(amount);
    return calculatePercentage(amount, fees);
  }

  int calculateSwapAmountFromReceivableAmount(int receivableAmount) {
    final claimFee = this.claimFee ?? 0;
    final serverNetworkFees = this.serverNetworkFees ?? 0;

    if (boltzPercent == null) {
      final boltzFee = this.boltzFee ?? 0;
      return receivableAmount + boltzFee + claimFee + serverNetworkFees;
    }

    final baseAmount = receivableAmount + claimFee + serverNetworkFees;
    final rate = 1.0 - (boltzPercent! / 100.0);

    int paymentAmount = (baseAmount / rate).ceil();

    int calculatedReceivable =
        paymentAmount -
        boltzFeeFromPercent(paymentAmount) -
        claimFee -
        serverNetworkFees;

    while (calculatedReceivable < receivableAmount) {
      paymentAmount++;
      calculatedReceivable =
          paymentAmount -
          boltzFeeFromPercent(paymentAmount) -
          claimFee -
          serverNetworkFees;
    }

    return paymentAmount;
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
    required String paymentAddress,
    required int paymentAmount,
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

  bool get requiresAction => switch (this) {
    LnReceiveSwap(:final status) => status == SwapStatus.claimable,
    LnSendSwap(:final status) =>
      status == SwapStatus.canCoop ||
          status == SwapStatus.failed ||
          status == SwapStatus.refundable,
    ChainSwap(:final status) =>
      status == SwapStatus.claimable || status == SwapStatus.refundable,
  };

  String? get txId => switch (this) {
    LnReceiveSwap(:final receiveTxid) => receiveTxid,
    LnSendSwap(:final sendTxid) => sendTxid,
    ChainSwap(:final sendTxid) => sendTxid,
  };

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

  int get amountSat => switch (this) {
    LnReceiveSwap(:final invoice) =>
      (Bolt11PaymentRequest(invoice).amount *
              Decimal.fromBigInt(ConversionConstants.satsAmountOfOneBitcoin))
          .toBigInt()
          .toInt(),
    LnSendSwap(:final invoice) =>
      (Bolt11PaymentRequest(invoice).amount *
              Decimal.fromBigInt(ConversionConstants.satsAmountOfOneBitcoin))
          .toBigInt()
          .toInt(),
    ChainSwap(:final paymentAmount) => paymentAmount,
  };

  String? get sendTxId => switch (this) {
    LnReceiveSwap() => null,
    LnSendSwap(:final sendTxid) => sendTxid,
    ChainSwap(:final sendTxid) => sendTxid,
  };

  String? get receiveTxId => switch (this) {
    LnReceiveSwap(:final receiveTxid) => receiveTxid,
    LnSendSwap() => null,
    ChainSwap(:final receiveTxid) => receiveTxid,
  };

  String get walletId => switch (this) {
    LnReceiveSwap(:final receiveWalletId) => receiveWalletId,
    LnSendSwap(:final sendWalletId) => sendWalletId,
    ChainSwap(:final sendWalletId) => sendWalletId,
  };

  bool get swapInProgress =>
      status == SwapStatus.paid ||
      status == SwapStatus.canCoop ||
      status == SwapStatus.claimable ||
      status == SwapStatus.refundable;

  bool get swapRefunded =>
      status == SwapStatus.completed &&
      ((this is ChainSwap && (this as ChainSwap).refundTxid != null) ||
          (this is LnSendSwap && (this as LnSendSwap).refundTxid != null));

  bool get isChainSwapInternal =>
      this is ChainSwap && (this as ChainSwap).receiveWalletId != null;

  bool get isChainSwapExternal =>
      this is ChainSwap && (this as ChainSwap).receiveWalletId == null;

  String get swapAction =>
      status == SwapStatus.claimable
          ? 'Claim'
          : status == SwapStatus.canCoop
          ? 'Close'
          : status == SwapStatus.refundable
          ? 'Refund'
          : '';

  bool get swapCompleted => status == SwapStatus.completed;

  bool get isBitcoin =>
      [
        SwapType.bitcoinToLightning,
        SwapType.lightningToBitcoin,
      ].contains(type) ||
      (type == SwapType.liquidToBitcoin && isChainSwapInternal ||
          type == SwapType.bitcoinToLiquid && !isChainSwapInternal);

  bool get isLiquid => [
    SwapType.liquidToLightning,
    SwapType.lightningToLiquid,
    SwapType.liquidToBitcoin,
    SwapType.bitcoinToLiquid,
  ].contains(type);
  String? get receiveAddress => switch (this) {
    LnReceiveSwap(:final receiveAddress) => receiveAddress,
    ChainSwap(:final receiveAddress) => receiveAddress,
    _ => null,
  };

  int? get receieveAmount => switch (this) {
    ChainSwap(:final paymentAmount, :final fees) => () {
      if (fees == null) return null;
      final totalSwapFees = fees.totalFeesMinusLockup(paymentAmount);
      return paymentAmount - totalSwapFees;
    }(),
    LnSendSwap(:final paymentAmount, :final fees) => () {
      if (fees == null) return null;
      final totalSwapFees = fees.totalFeesMinusLockup(paymentAmount);
      return paymentAmount - totalSwapFees;
    }(),
    LnReceiveSwap(:final invoice, :final fees) => () {
      if (fees == null) return null;
      final invoiceAmount =
          (Bolt11PaymentRequest(invoice).amount *
                  Decimal.fromBigInt(
                    ConversionConstants.satsAmountOfOneBitcoin,
                  ))
              .toBigInt()
              .toInt();
      final totalFees = fees.totalFees(invoiceAmount);
      return invoiceAmount - totalFees;
    }(),
  };

  int? get sendAmount => switch (this) {
    ChainSwap(:final paymentAmount, :final fees) => () {
      if (fees == null) return null;
      return paymentAmount;
    }(),
    LnSendSwap(:final paymentAmount, :final fees) => () {
      if (fees == null) return null;
      return paymentAmount;
    }(),
    LnReceiveSwap(:final invoice) => () {
      final invoiceAmount =
          (Bolt11PaymentRequest(invoice).amount *
                  Decimal.fromBigInt(
                    ConversionConstants.satsAmountOfOneBitcoin,
                  ))
              .toBigInt()
              .toInt();
      return invoiceAmount;
    }(),
  };
}

extension SwapFeePercent on Swap {
  double getFeeAsPercentOfAmount() {
    final fees = this.fees;
    final amount = amountSat;
    if (fees == null || amount == 0) return 0.0;
    final totalFees = fees.totalFees(amount);
    return calculatePercentage(amount, totalFees);
  }

  bool showFeeWarning() {
    final feePercent = getFeeAsPercentOfAmount();
    return feePercent > 5.0;
  }
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

extension SwapStatusMessage on Swap {
  String getDisplayMessage() {
    if (isLnReceiveSwap) {
      switch (status) {
        case SwapStatus.pending:
          return "Swap is not yet initialized.";
        case SwapStatus.paid:
          return "Sender has paid the invoice.";
        case SwapStatus.claimable:
          return "Swap is ready to be claimed.";
        case SwapStatus.refundable:
          return "Swap is ready to be refunded.";
        case SwapStatus.canCoop:
          return "Swap will complete momentarily.";
        case SwapStatus.completed:
          return "Swap is completed.";
        case SwapStatus.expired:
          return "Swap Expired.";
        case SwapStatus.failed:
          return "Swap Failed.";
      }
    } else if (isLnSendSwap) {
      switch (status) {
        case SwapStatus.pending:
          return "Swap is not yet initialized.";
        case SwapStatus.paid:
          return "Invoice will be paid after you payment receives confirmation.";
        case SwapStatus.claimable:
          return "Swap is ready to be claimed.";
        case SwapStatus.refundable:
          return "Swap is ready to be refunded.";
        case SwapStatus.canCoop:
          return "Swap will complete momentarily.";
        case SwapStatus.completed:
          final swap = this;
          if (swap is LnSendSwap && swap.refundTxid != null) {
            return "Swap has been refunded.";
          } else {
            return "Swap is completed successfully.";
          }
        case SwapStatus.expired:
          return "Swap Expired";
        case SwapStatus.failed:
          final swap = this;
          if (swap is LnSendSwap && swap.sendTxid != null) {
            return "Swap will be refunded shortly.";
          } else {
            return "Swap Failed.";
          }
      }
    } else if (isChainSwap) {
      switch (status) {
        case SwapStatus.pending:
          return "Transfer is not yet initialized.";
        case SwapStatus.paid:
          return "Waiting for transfer provider's payment to receive confirmation. This may take a while to complete.";
        case SwapStatus.claimable:
          return "Transfer is ready to be claimed.";
        case SwapStatus.refundable:
          return "Transfer is ready to be refunded.";
        case SwapStatus.canCoop:
          return "Transfer will complete momentarily.";
        case SwapStatus.completed:
          final swap = this;
          if (swap is ChainSwap && swap.refundTxid != null) {
            return "Transfer has been refunded.";
          } else {
            return "Transfer is completed successfully.";
          }
        case SwapStatus.expired:
          return "Transfer Expired";
        case SwapStatus.failed:
          final swap = this;
          if (swap is ChainSwap && swap.sendTxid != null) {
            return "Transfer will be refunded shortly.";
          } else {
            return "Transfer Failed.";
          }
      }
    }
    return "";
  }
}
