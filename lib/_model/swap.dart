// ignore_for_file: invalid_annotation_target

import 'package:bb_mobile/_model/transaction.dart' as bb;
import 'package:bb_mobile/_model/wallet.dart';
import 'package:boltz_dart/boltz_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'swap.freezed.dart';
part 'swap.g.dart';

enum OnChainSwapType { selfSwap, receiveSwap, sendSwap }

enum SwapTxType { lockup, claim }

@freezed
class ChainSwapDetails with _$ChainSwapDetails {
  const factory ChainSwapDetails({
    required ChainSwapDirection direction,
    required OnChainSwapType onChainType,
    required int refundKeyIndex,
    required String refundSecretKey,
    required String refundPublicKey,
    required int claimKeyIndex,
    required String claimSecretKey,
    required String claimPublicKey,
    required int lockupLocktime,
    required int claimLocktime,
    required String btcElectrumUrl,
    required String lbtcElectrumUrl,
    required String blindingKey, //TODO:onchain sensitive
    required String btcFundingAddress,
    required String btcScriptSenderPublicKey,
    required String btcScriptReceiverPublicKey,
    required String lbtcFundingAddress,
    required String lbtcScriptSenderPublicKey,
    required String lbtcScriptReceiverPublicKey,
    required String toWalletId,
  }) = _ChainSwapDetails;

  const ChainSwapDetails._();
  factory ChainSwapDetails.fromJson(Map<String, dynamic> json) =>
      _$ChainSwapDetailsFromJson(json);
}

@freezed
class LnSwapDetails with _$LnSwapDetails {
  const factory LnSwapDetails({
    required SwapType swapType,
    required String invoice,
    required String boltzPubKey,
    required int keyIndex,
    required String myPublicKey,
    required String sha256,
    required String electrumUrl,
    required int locktime,
    String? hash160,
    String? blindingKey, // sensitive
  }) = _LnSwapDetails;

  const LnSwapDetails._();
  factory LnSwapDetails.fromJson(Map<String, dynamic> json) =>
      _$LnSwapDetailsFromJson(json);
}

@freezed
class SwapTx with _$SwapTx {
  const factory SwapTx({
    required String id,
    required BBNetwork network,
    required BaseWalletType walletType,
    required int outAmount,
    required String scriptAddress,
    required String boltzUrl,
    ChainSwapDetails? chainSwapDetails,
    LnSwapDetails? lnSwapDetails,
    String? claimTxid, // reverse + chain.self
    String? lockupTxid, // submarine + chain.sendSwap + chain.sendSwap
    String? label,
    SwapStreamStatus? status, // should this be SwapStaus?
    int? boltzFees,
    int? lockupFees,
    int? claimFees,
    String? claimAddress,
    String? refundAddress,
    DateTime? creationTime,
    DateTime? completionTime,
  }) = _SwapTx;
  factory SwapTx.fromJson(Map<String, dynamic> json) => _$SwapTxFromJson(json);

  const SwapTx._();

  String? getDuration() {
    if (completionTime == null) {
      return null;
    }
    final minutes = completionTime!.difference(creationTime!).inMinutes;
    if (minutes == 0) {
      final seconds = completionTime?.difference(creationTime!).inSeconds;
      return '$seconds seconds';
    } else if (minutes > 60) {
      final hours = completionTime?.difference(creationTime!).inHours;
      return '$hours hours';
    } else {
      return '$minutes minutes';
    }
  }

  int? amountForDisplay() {
    if (isSubmarine()) {
      return outAmount - (claimFees ?? 0) - (boltzFees ?? 0);
    } else if (isReverse()) {
      return outAmount;
    }
    return outAmount;
  }

  bool noClaimTxid() => claimTxid == null;
  bool noLockupTxid() => lockupTxid == null;

  // lockup: submarine, chain.self (lbtc->btc), chain.send
  // claim: reverse , chain.recieve
  String? getParentTxid() {
    if (isSubmarine()) {
      return lockupTxid;
    }
    if (isReverse()) {
      return claimTxid;
    }
    if (isChainSelf()) {
      return lockupTxid;
    }
    if (isChainReceive()) {
      return claimTxid;
    }
    if (isChainSend()) {
      return lockupTxid;
    }
    return null;
  }

  // return the swapTxType that needs to be updated for liquid swap tx broadcast
  SwapTxType getSwapTxTypeForParent() {
    if (isSubmarine()) {
      return SwapTxType.lockup;
    }
    if (isReverse()) {
      return SwapTxType.claim;
    }
    if (isChainSelf()) {
      return SwapTxType.lockup;
    }
    if (isChainReceive()) {
      return SwapTxType.claim;
    }
    if (isChainSend()) {
      return SwapTxType.lockup;
    } else {
      return SwapTxType.lockup; // should never reach
    }
  }

  bool isTestnet() => network == BBNetwork.Testnet;

  bool isLiquid() => walletType == BaseWalletType.Liquid;
  bool isBitcoin() => walletType == BaseWalletType.Bitcoin;

  int? totalFees() {
    if (boltzFees == null || lockupFees == null || claimFees == null) {
      return null;
    }

    return boltzFees! + lockupFees! + claimFees!;
  }

  int? recievableAmount() {
    if (totalFees() == null) return null;
    return outAmount - totalFees()!;
  }

  bool isLnSwap() => lnSwapDetails != null;
  bool isChainSwap() => chainSwapDetails != null;
  bool isSubmarine() =>
      isLnSwap() && lnSwapDetails!.swapType == SwapType.submarine;
  bool isReverse() => isLnSwap() && lnSwapDetails!.swapType == SwapType.reverse;
  bool isChainSelf() =>
      isChainSwap() &&
      chainSwapDetails!.onChainType == OnChainSwapType.selfSwap;
  bool isChainSend() =>
      isChainSwap() &&
      chainSwapDetails!.onChainType == OnChainSwapType.sendSwap;
  bool isChainReceive() =>
      isChainSwap() &&
      chainSwapDetails!.onChainType == OnChainSwapType.receiveSwap;

  bool paidSubmarine() =>
      isSubmarine() &&
      (status != null && (status!.status == SwapStatus.invoicePaid));

  bool settledSubmarine() =>
      isSubmarine() &&
      (status != null && (status!.status == SwapStatus.txnClaimed));

  bool refundableSubmarine() =>
      isSubmarine() &&
      (status != null &&
          (status!.status == SwapStatus.invoiceFailedToPay ||
              status!.status == SwapStatus.txnLockupFailed ||
              (lockupTxid != null &&
                  status!.status == SwapStatus.swapExpired)));

  bool refundableOnchain() =>
      isChainSwap() &&
      status != null &&
      claimTxid == null &&
      (status!.status == SwapStatus.txnLockupFailed ||
          (lockupTxid != null &&
              (status!.status == SwapStatus.swapExpired ||
                  status!.status == SwapStatus.txnFailed ||
                  status!.status == SwapStatus.txnRefunded)));

  bool refundedAny() =>
      status != null &&
      (status!.status == SwapStatus.swapRefunded ||
          status!.status == SwapStatus.txnRefunded ||
          (lockupTxid != null && status!.status == SwapStatus.swapExpired)) &&
      claimTxid != null;

  bool claimableSubmarine() =>
      isSubmarine() &&
      status != null &&
      (status!.status == SwapStatus.txnClaimPending);

  bool expiredSubmarine() =>
      isSubmarine() &&
      (status != null && (status!.status == SwapStatus.swapExpired));

  bool claimableReverse() =>
      isReverse() &&
      status != null &&
      ((status!.status == SwapStatus.txnConfirmed) ||
          (status!.status == SwapStatus.invoiceSettled && claimTxid == null));

  // TODO: Is this right
  bool claimableOnchain() =>
      isChainSwap() &&
      status != null &&
      ((status!.status == SwapStatus.txnServerConfirmed ||
              status!.status == SwapStatus.txnClaimed) &&
          claimTxid == null); //  ||
  // (status!.status == SwapStatus.invoiceSettled && txid == null));

  bool expiredReverse() =>
      isReverse() &&
      (status != null &&
          (status!.status == SwapStatus.invoiceExpired ||
              status!.status == SwapStatus.swapExpired));

  bool expiredOnchain() =>
      isChainSwap() &&
      lockupTxid == null &&
      (status != null && (status!.status == SwapStatus.swapExpired));

  bool settledReverse() =>
      isReverse() &&
      claimTxid != null &&
      (status != null && (status!.status == SwapStatus.invoiceSettled));

  bool settledOnchain() =>
      isChainSwap() &&
      claimTxid != null &&
      (status != null && (status!.status == SwapStatus.txnClaimed));

  bool refundedOnchain() =>
      isChainSwap() &&
      claimTxid != null &&
      status != null &&
      (status!.status == SwapStatus.swapRefunded ||
          status!.status == SwapStatus.swapExpired);

  bool paidReverse() =>
      isReverse() &&
      (status != null && (status!.status == SwapStatus.txnMempool));

  bool paidOnchain() =>
      isChainSwap() &&
      (status != null &&
          (status!.status == SwapStatus.txnMempool ||
              status!.status == SwapStatus.txnConfirmed));

  bool uninitiatedOnchain() =>
      isChainSwap() &&
      creationTime!.difference(DateTime.now()).inDays > 3 &&
      (status != null && (status!.status == SwapStatus.swapCreated));

  bool receiveAction() => settledReverse() || paidReverse();

  bool proceesTx() =>
      paidSubmarine() ||
      settledReverse() ||
      settledSubmarine() ||
      refundableOnchain() ||
      refundableSubmarine() ||
      paidReverse() ||
      refundedAny() ||
      paidOnchain();

  bool close() =>
      settledReverse() ||
      settledSubmarine() ||
      expiredReverse() ||
      expiredSubmarine() ||
      refundedAny() ||
      expiredOnchain() ||
      uninitiatedOnchain() ||
      settledOnchain();

  bool failed() => isChainSwap()
      ? isChainSwapFailed()
      : isReverse()
          ? reverseSwapAction() == ReverseSwapActions.failed
          : submarineSwapAction() == SubmarineSwapActions.failed;

  //TODO:Onchain
  bool isChainSwapFailed() {
    return status?.status == SwapStatus.txnFailed;
  }

  String splitInvoice() =>
      '${lnSwapDetails!.invoice.substring(0, 5)} .... ${lnSwapDetails!.invoice.substring(lnSwapDetails!.invoice.length - 10)}';

  bool smallAmt() => outAmount < 1000000;

  double? highFees() {
    final fee = totalFees();
    if (fee == null) return null;
    final feesPercent = (fee / outAmount) * 100;
    if (feesPercent > 3) return feesPercent;
    return null;
  }

  String actionPrefixStr() {
    if (isSubmarine()) {
      if (paidSubmarine()) return 'Outgoing';
      if (settledSubmarine() || claimableSubmarine()) return 'Sent';
      return 'Outgoing';
    } else {
      if (paidReverse()) return 'Incoming';
      if (settledReverse()) return 'Received';
      return 'Incoming';
    }
  }

  ReverseSwapActions reverseSwapAction() {
    if (!isReverse()) throw 'Swap is not reverse!';
    final statuss = status?.status;

    if (statuss == null || statuss == SwapStatus.swapCreated) {
      return ReverseSwapActions.created;
    } else if (expiredReverse() ||
        statuss == SwapStatus.swapError ||
        statuss == SwapStatus.txnFailed ||
        statuss == SwapStatus.txnLockupFailed) {
      return ReverseSwapActions.failed;
    } else if (paidReverse()) {
      return ReverseSwapActions.paid;
    } else if (claimableReverse()) {
      return ReverseSwapActions.claimable;
    } else if (settledReverse()) {
      return ReverseSwapActions.settled;
    } else {
      return ReverseSwapActions.created;
    }
  }

  SubmarineSwapActions submarineSwapAction() {
    if (!isSubmarine()) throw 'Swap is not submarine!';
    final statuss = status?.status;

    if (statuss == null || statuss == SwapStatus.swapCreated) {
      return SubmarineSwapActions.created;
    } else if (expiredSubmarine() ||
        statuss == SwapStatus.swapExpired ||
        statuss == SwapStatus.swapError ||
        statuss == SwapStatus.txnFailed) {
      return SubmarineSwapActions.failed;
    } else if (paidSubmarine()) {
      return SubmarineSwapActions.paid;
    } else if (claimableSubmarine()) {
      return SubmarineSwapActions.claimable;
    } else if (settledSubmarine()) {
      return SubmarineSwapActions.settled;
    } else if (refundableSubmarine()) {
      return SubmarineSwapActions.refundable;
    } else {
      return SubmarineSwapActions.created;
    }
  }

  // TODO:Onchain: Overlap between refundable and expired
  ChainSwapActions chainSwapAction() {
    if (!isChainSwap()) throw 'Swap is not chainswap!';
    final statuss = status?.status;

    if (statuss == null || statuss == SwapStatus.swapCreated) {
      return ChainSwapActions.created;
    } else if (paidOnchain()) {
      return ChainSwapActions.paid;
    } else if (claimableOnchain()) {
      return ChainSwapActions.claimable;
    } else if (refundableOnchain()) {
      return ChainSwapActions.refundable;
    } else if (statuss == SwapStatus.swapError ||
        statuss == SwapStatus.txnFailed) {
      return ChainSwapActions.failed;
    } else if (settledOnchain()) {
      return ChainSwapActions.settled;
    } else if (refundedOnchain()) {
      return ChainSwapActions.refunded;
    } else {
      return ChainSwapActions.created;
    }
  }

  bool showAlert() {
    if (isChainSwap()) {
      if (paidOnchain() || settledOnchain()) return true;
    } else if (isSubmarine()) {
      if (paidSubmarine() || settledSubmarine()) return true;
    } else {
      if (paidReverse() || settledReverse()) return true;
    }
    return false;
  }

  bool syncWallet() {
    if (isChainSwap()) {
      if (claimableOnchain() || refundableOnchain() || settledOnchain()) {
        return true;
      }
    } else if (isSubmarine()) {
      if (claimableSubmarine() || refundableSubmarine() || settledSubmarine()) {
        return true;
      }
    } else {
      if (claimableReverse() || settledReverse()) return true;
    }
    return false;
  }

  bb.Transaction toNewTransaction() {
    final txId = isLnSwap()
        ? (lnSwapDetails!.swapType == SwapType.submarine
            ? lockupTxid
            : claimTxid)
        : isChainSwap()
            ? lockupTxid
            : isChainReceive()
                ? claimTxid
                : lockupTxid;
    final newTx = bb.Transaction(
      txid: txId ?? id,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      swapTx: this,
      sent: !isSubmarine() ? 0 : outAmount - totalFees()!,
      isSwap: true,
      received: !isSubmarine() ? (outAmount - (totalFees() ?? 0)) : 0,
      fee: !isSubmarine() ? claimFees : lockupFees,
      isLiquid: isLiquid(),
      label: label,
    );
    return newTx;
  }
}

enum ReverseSwapActions {
  created,
  failed,
  paid,
  claimable,
  settled,
}

enum SubmarineSwapActions {
  created,
  failed,
  paid,
  claimable,
  refundable,
  settled,
}

enum ChainSwapActions {
  created,
  failed,
  paid,
  claimable,
  refundable,
  settled,
  refunded,
}

@freezed
class LnSwapTxSensitive with _$LnSwapTxSensitive {
  const factory LnSwapTxSensitive({
    required String id,
    required String secretKey,
    required String publicKey,
    required String preimage,
    required String sha256,
    required String hash160,
    String? boltzPubkey,
    bool? isSubmarine,
    String? scriptAddress,
    int? locktime,
    String? blindingKey,
  }) = _LnSwapTxSensitive;
  const LnSwapTxSensitive._();

  factory LnSwapTxSensitive.fromJson(Map<String, dynamic> json) =>
      _$LnSwapTxSensitiveFromJson(json);
}

@freezed
class ChainSwapTxSensitive with _$ChainSwapTxSensitive {
  const factory ChainSwapTxSensitive({
    required String id,
    required String refundKeySecret,
    required String claimKeySecret,
    required String preimage,
    required String sha256,
    required String hash160,
    required String blindingKey,
  }) = _ChainSwapTxSensitive;

  factory ChainSwapTxSensitive.fromJson(Map<String, dynamic> json) =>
      _$ChainSwapTxSensitiveFromJson(json);
}

@freezed
class Invoice with _$Invoice {
  const factory Invoice({
    required int msats,
    required int expiry,
    required int expiresIn,
    required int expiresAt,
    required bool isExpired,
    required String network,
    required int cltvExpDelta,
    required String invoice,
    String? bip21,
  }) = _Invoice;
  const Invoice._();

  factory Invoice.fromJson(Map<String, dynamic> json) =>
      _$InvoiceFromJson(json);

  factory Invoice.fromDecodedInvoice(
    DecodedInvoice decodedInvoice,
    String invoice,
  ) {
    return Invoice(
      invoice: invoice,
      msats: decodedInvoice.msats.toInt(),
      expiry: decodedInvoice.expiry.toInt(),
      expiresIn: decodedInvoice.expiresIn.toInt(),
      expiresAt: decodedInvoice.expiresAt.toInt(),
      isExpired: decodedInvoice.isExpired,
      network: decodedInvoice.network,
      cltvExpDelta: decodedInvoice.cltvExpDelta.toInt(),
      bip21: decodedInvoice.bip21,
    );
  }

  int getAmount() => msats ~/ 1000;

  bool? isTestnet() {
    if (network == 'testnet') return true;
    if (network == 'bitcoin') return false;
    return null;
  }
}

enum PaymentNetwork { bitcoin, liquid, lightning }

extension X on SwapStatus? {
  (String, String)? getOnChainStr(OnChainSwapType type) {
    (String, String) status = ('', '');
    switch (this) {
      case SwapStatus.swapCreated:
        status =
            ('Created', 'Swap has been created but no payment has been made.');
      case SwapStatus.swapExpired:
        status = ('Expired', 'Swap has expired');
      case SwapStatus.swapRefunded:
        status = ('Refunded', 'Swap has been successfully refunded');
      case SwapStatus.swapError:
        status = ('Error', 'Swap was unsuccessful');
      case SwapStatus.txnMempool:
        if (type == OnChainSwapType.selfSwap ||
            type == OnChainSwapType.sendSwap) {
          status = (
            'Mempool',
            'You have paid the swap lockup transaction. Waiting for block confirmation'
          );
        } else {
          status = (
            'Mempool',
            'Your sender have paid the swap lockup transaction. Waiting for block confirmation'
          );
        }

      /// TODO: This happens with onchain swap?
      case SwapStatus.txnClaimPending:
        status = (
          'Claim Pending',
          'The lightning invoice has been paid. Waiting for Boltz to complete the swap.'
        );
      case SwapStatus.txnClaimed:
        status = ('Claimed', 'The swap is completed.');
      case SwapStatus.txnConfirmed:
        if (type == OnChainSwapType.selfSwap ||
            type == OnChainSwapType.sendSwap) {
          status = (
            'Confirmed',
            'Your lockup transaction is confirmed. Waiting for Boltz lockup'
          );
        } else {
          status = (
            'Confirmed',
            "Your sender's lockup transaction is confirmed. Waiting for Boltz lockup"
          );
        }
      case SwapStatus.txnRefunded:
        status = ('Refunded', 'The swap has been successfully refunded.');
      case SwapStatus.txnFailed:
        status = ('Transaction Failed', 'The swap will be refunded.');
      case SwapStatus.txnLockupFailed:
        status = ('Transaction Lockup Failed', 'The swap will be refunded.');

      /// TODO: This happens with onchain swap?
      case SwapStatus.invoiceSet:
        status = ('Invoice Set', 'The invoice for the swap has been set.');

      /// TODO: This happens with onchain swap?
      case SwapStatus.invoicePending:
        status = (
          'Invoice Pending',
          'Onchain transaction confirmed. Payment of the invoice is in progress.'
        );

      /// TODO: This happens with onchain swap?
      case SwapStatus.invoicePaid:
        status = ('Invoice Paid', 'The invoice has been successfully paid.');

      /// TODO: This happens with onchain swap?
      case SwapStatus.invoiceFailedToPay:
        status = (
          'Failed to pay invoice',
          'The invoice has failed to pay. This transaction will be refunded.'
        );

      /// TODO: This happens with onchain swap?
      case SwapStatus.invoiceSettled:
        status = (
          'Invoice Settled',
          'The invoice has settled and the swap is completed.'
        );

      /// TODO: This happens with onchain swap?
      case SwapStatus.invoiceExpired:
        status = (
          'Invoice Expired',
          'The invoice has expirted. Swap will be deleted.'
        );

      /// TODO: This happens with onchain swap?
      case SwapStatus.minerfeePaid:
        status = ('Miner Fee Paid.', '');
      case SwapStatus.txnServerMempool:
        status = (
          'Boltz Mempool',
          'Boltz has made their payment. You can claim once this is confirmed'
        );
      case SwapStatus.txnServerConfirmed:
        status = (
          'Boltz Confirmed',
          'Boltz payment is confirmed. You can claim the onchain swap'
        );
      case null:
        return null;
    }
    return status;
  }

  (String, String)? getStr(bool isSubmarine) {
    (String, String) status = ('', '');
    switch (this) {
      case SwapStatus.swapCreated:
        status =
            ('Created', 'Swap has been created but no payment has been made.');
      case SwapStatus.swapExpired:
        status = ('Expired', 'Swap has expired');
      case SwapStatus.swapRefunded:
        status = ('Refunded', 'Swap has been successfully refunded');
      case SwapStatus.swapError:
        status = ('Error', 'Swap was unsuccessful');
      case SwapStatus.txnMempool:
        status = (
          'Mempool',
          isSubmarine
              ? 'You have paid the swap lockup transaction. The invoice will be paid as soon as the transaction is confirmed.'
              : 'Sender has paid the invoice and Boltz has made the lockup transaction. You will be able to claim it as soon as the transaction is confirmed.'
        );
      case SwapStatus.txnClaimPending:
        status = (
          'Claim Pending',
          'The lightning invoice has been paid. Waiting for Boltz to complete the swap.'
        );
      case SwapStatus.txnClaimed:
        status = ('Claimed', 'The swap is completed.');
      case SwapStatus.txnConfirmed:
        status = (
          'Confirmed',
          isSubmarine
              ? 'Your lockup transaction is confirmed. The invoice will be paid momentarily.'
              : 'Boltz lockup transaction is confirmed. The swap will be claimed and you will recieve funds after the claim transaction gets confirmed.'
        );
      case SwapStatus.txnRefunded:
        status = ('Refunded', 'The swap has been successfully refunded.');
      case SwapStatus.txnFailed:
        status = (
          'Transaction Failed',
          'If a payment was made, it will be refunded.'
        );
      case SwapStatus.txnLockupFailed:
        status = ('Transaction Lockup Failed', 'The swap will be refunded.');
      case SwapStatus.invoiceSet:
        status = (
          'Invoice Set',
          'The invoice for the swap has been set. Waiting for an onchain payment to be made. Swap will expire if an onchain payment is not made.'
        );
      case SwapStatus.invoicePending:
        status = (
          'Invoice Pending',
          'Onchain transaction confirmed. Payment of the invoice is in progress.'
        );
      case SwapStatus.invoicePaid:
        status = ('Invoice Paid', 'The invoice has been successfully paid.');
      case SwapStatus.invoiceFailedToPay:
        status = (
          'Failed to pay invoice',
          'The invoice has failed to pay. This transaction will be refunded.'
        );
      case SwapStatus.invoiceSettled:
        status = (
          'Invoice Settled',
          'The invoice has settled and the swap is completed.'
        );
      case SwapStatus.invoiceExpired:
        status = (
          'Invoice Expired',
          'The invoice has expirted. Swap will be deleted.'
        );
      case SwapStatus.minerfeePaid:
        status = ('Miner Fee Paid.', '');
      case SwapStatus.txnServerMempool:
        status = (
          'Boltz Mempool',
          'Boltz has made their payment. You can claim once this is confirmed'
        );
      case SwapStatus.txnServerConfirmed:
        status = (
          'Boltz Confirmed',
          'Boltz payment is confirmed. You can claim the onchain swap'
        );
      case null:
        return null;
    }
    return status;
  }
}
