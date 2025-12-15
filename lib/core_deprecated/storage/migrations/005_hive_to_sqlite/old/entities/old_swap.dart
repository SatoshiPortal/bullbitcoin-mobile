// ignore_for_file: invalid_annotation_target

import 'package:bb_mobile/core_deprecated/storage/migrations/005_hive_to_sqlite/old/entities/old_transaction.dart';
import 'package:bb_mobile/core_deprecated/storage/migrations/005_hive_to_sqlite/old/entities/old_wallet.dart';
import 'package:boltz/boltz.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'old_swap.freezed.dart';
part 'old_swap.g.dart';

class OldBBNetworkConverter implements JsonConverter<OldBBNetwork, String> {
  const OldBBNetworkConverter();

  @override
  OldBBNetwork fromJson(String json) => OldBBNetwork.values.firstWhere(
    (e) => e.toString() == 'OldBBNetwork.$json',
    orElse: () => OldBBNetwork.Mainnet,
  );

  @override
  String toJson(OldBBNetwork object) => object.toString().split('.').last;
}

enum OldOnChainSwapType { selfSwap, receiveSwap, sendSwap }

enum OldSwapTxType { lockup, claim }

@freezed
abstract class OldChainSwapDetails with _$OldChainSwapDetails {
  const factory OldChainSwapDetails({
    required ChainSwapDirection direction,
    required OldOnChainSwapType onChainType,
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
  }) = _OldChainSwapDetails;

  const OldChainSwapDetails._();
  factory OldChainSwapDetails.fromJson(Map<String, dynamic> json) =>
      _$OldChainSwapDetailsFromJson(json);
}

@freezed
abstract class OldLnSwapDetails with _$OldLnSwapDetails {
  const factory OldLnSwapDetails({
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
  }) = _OldLnSwapDetails;

  const OldLnSwapDetails._();
  factory OldLnSwapDetails.fromJson(Map<String, dynamic> json) =>
      _$OldLnSwapDetailsFromJson(json);
}

@freezed
abstract class OldSwapTx with _$OldSwapTx {
  const factory OldSwapTx({
    required String id,
    @OldBBNetworkConverter() required OldBBNetwork network,
    required OldBaseWalletType walletType,
    required int outAmount,
    required String scriptAddress,
    required String boltzUrl,
    OldChainSwapDetails? chainSwapDetails,
    OldLnSwapDetails? lnSwapDetails,
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
  factory OldSwapTx.fromJson(Map<String, dynamic> json) =>
      _$OldSwapTxFromJson(json);

  const OldSwapTx._();

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
  OldSwapTxType getSwapTxTypeForParent() {
    if (isSubmarine()) {
      return OldSwapTxType.lockup;
    }
    if (isReverse()) {
      return OldSwapTxType.claim;
    }
    if (isChainSelf()) {
      return OldSwapTxType.lockup;
    }
    if (isChainReceive()) {
      return OldSwapTxType.claim;
    }
    if (isChainSend()) {
      return OldSwapTxType.lockup;
    } else {
      return OldSwapTxType.lockup; // should never reach
    }
  }

  bool isTestnet() => network == OldBBNetwork.Testnet;

  bool isLiquid() => walletType == OldBaseWalletType.Liquid;
  bool isBitcoin() => walletType == OldBaseWalletType.Bitcoin;

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
      chainSwapDetails!.onChainType == OldOnChainSwapType.selfSwap;
  bool isChainSend() =>
      isChainSwap() &&
      chainSwapDetails!.onChainType == OldOnChainSwapType.sendSwap;
  bool isChainReceive() =>
      isChainSwap() &&
      chainSwapDetails!.onChainType == OldOnChainSwapType.receiveSwap;

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

  bool failed() =>
      isChainSwap()
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

  OldTransaction toNewTransaction() {
    final txId =
        isLnSwap()
            ? (lnSwapDetails!.swapType == SwapType.submarine
                ? lockupTxid
                : claimTxid)
            : isChainSwap()
            ? lockupTxid
            : isChainReceive()
            ? claimTxid
            : lockupTxid;
    final newTx = OldTransaction(
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

enum ReverseSwapActions { created, failed, paid, claimable, settled }

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
abstract class OldLnSwapTxSensitive with _$OldLnSwapTxSensitive {
  const factory OldLnSwapTxSensitive({
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
  const OldLnSwapTxSensitive._();

  factory OldLnSwapTxSensitive.fromJson(Map<String, dynamic> json) =>
      _$LnSwapTxSensitiveFromJson(json);
}

@freezed
abstract class OldChainSwapTxSensitive with _$OldChainSwapTxSensitive {
  const factory OldChainSwapTxSensitive({
    required String id,
    required String refundKeySecret,
    required String claimKeySecret,
    required String preimage,
    required String sha256,
    required String hash160,
    required String blindingKey,
  }) = _OldChainSwapTxSensitive;

  factory OldChainSwapTxSensitive.fromJson(Map<String, dynamic> json) =>
      _$OldChainSwapTxSensitiveFromJson(json);
}

@freezed
abstract class OldInvoice with _$OldInvoice {
  const factory OldInvoice({
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
  const OldInvoice._();

  factory OldInvoice.fromJson(Map<String, dynamic> json) =>
      _$InvoiceFromJson(json);

  factory OldInvoice.fromDecodedInvoice(
    DecodedInvoice decodedInvoice,
    String invoice,
  ) {
    return OldInvoice(
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

enum OldPaymentNetwork { bitcoin, liquid, lightning }

extension OldX on SwapStatus? {
  (String, String)? getOnChainStr(OldOnChainSwapType type) {
    (String, String) status = ('', '');
    switch (this) {
      case SwapStatus.swapCreated:
        status = (
          'Created',
          'Swap has been created but no payment has been made.',
        );
      case SwapStatus.swapExpired:
        status = ('Expired', 'Swap has expired');
      case SwapStatus.swapRefunded:
        status = ('Refunded', 'Swap has been successfully refunded');
      case SwapStatus.swapError:
        status = ('Error', 'Swap was unsuccessful');
      case SwapStatus.txnMempool:
        if (type == OldOnChainSwapType.selfSwap ||
            type == OldOnChainSwapType.sendSwap) {
          status = (
            'Mempool',
            'You have paid the swap lockup transaction. Waiting for block confirmation',
          );
        } else {
          status = (
            'Mempool',
            'Your sender have paid the swap lockup transaction. Waiting for block confirmation',
          );
        }

      /// TODO: This happens with onchain swap?
      case SwapStatus.txnClaimPending:
        status = (
          'Claim Pending',
          'The lightning invoice has been paid. Waiting for Boltz to complete the swap.',
        );
      case SwapStatus.txnClaimed:
        status = ('Claimed', 'The swap is completed.');
      case SwapStatus.txnConfirmed:
        if (type == OldOnChainSwapType.selfSwap ||
            type == OldOnChainSwapType.sendSwap) {
          status = (
            'Confirmed',
            'Your lockup transaction is confirmed. Waiting for Boltz lockup',
          );
        } else {
          status = (
            'Confirmed',
            "Your sender's lockup transaction is confirmed. Waiting for Boltz lockup",
          );
        }
      case SwapStatus.txnRefunded:
        status = ('Refunded', 'The swap has been successfully refunded.');
      case SwapStatus.txnFailed:
        status = ('OldTransaction Failed', 'The swap will be refunded.');
      case SwapStatus.txnLockupFailed:
        status = ('OldTransaction Lockup Failed', 'The swap will be refunded.');

      /// TODO: This happens with onchain swap?
      case SwapStatus.invoiceSet:
        status = ('OldInvoice Set', 'The invoice for the swap has been set.');

      /// TODO: This happens with onchain swap?
      case SwapStatus.invoicePending:
        status = (
          'OldInvoice Pending',
          'Onchain transaction confirmed. Payment of the invoice is in progress.',
        );

      /// TODO: This happens with onchain swap?
      case SwapStatus.invoicePaid:
        status = ('OldInvoice Paid', 'The invoice has been successfully paid.');

      /// TODO: This happens with onchain swap?
      case SwapStatus.invoiceFailedToPay:
        status = (
          'Failed to pay invoice',
          'The invoice has failed to pay. This transaction will be refunded.',
        );

      /// TODO: This happens with onchain swap?
      case SwapStatus.invoiceSettled:
        status = (
          'OldInvoice Settled',
          'The invoice has settled and the swap is completed.',
        );

      /// TODO: This happens with onchain swap?
      case SwapStatus.invoiceExpired:
        status = (
          'OldInvoice Expired',
          'The invoice has expirted. Swap will be deleted.',
        );

      /// TODO: This happens with onchain swap?
      case SwapStatus.minerfeePaid:
        status = ('Miner Fee Paid.', '');
      case SwapStatus.txnServerMempool:
        status = (
          'Boltz Mempool',
          'Boltz has made their payment. You can claim once this is confirmed',
        );
      case SwapStatus.txnServerConfirmed:
        status = (
          'Boltz Confirmed',
          'Boltz payment is confirmed. You can claim the onchain swap',
        );
      case null:
        return null;
      case SwapStatus.txnDirect:
        status = (
          'Direct Transaction',
          'A direct transaction has been made and the swap has been bypassed.',
        );
        throw UnimplementedError();
    }
    return status;
  }

  (String, String)? getStr(bool isSubmarine) {
    (String, String) status = ('', '');
    switch (this) {
      case SwapStatus.swapCreated:
        status = (
          'Created',
          'Swap has been created but no payment has been made.',
        );
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
              : 'Sender has paid the invoice and Boltz has made the lockup transaction. You will be able to claim it as soon as the transaction is confirmed.',
        );
      case SwapStatus.txnClaimPending:
        status = (
          'Claim Pending',
          'The lightning invoice has been paid. Waiting for Boltz to complete the swap.',
        );
      case SwapStatus.txnClaimed:
        status = ('Claimed', 'The swap is completed.');
      case SwapStatus.txnConfirmed:
        status = (
          'Confirmed',
          isSubmarine
              ? 'Your lockup transaction is confirmed. The invoice will be paid momentarily.'
              : 'Boltz lockup transaction is confirmed. The swap will be claimed and you will recieve funds after the claim transaction gets confirmed.',
        );
      case SwapStatus.txnRefunded:
        status = ('Refunded', 'The swap has been successfully refunded.');
      case SwapStatus.txnFailed:
        status = (
          'OldTransaction Failed',
          'If a payment was made, it will be refunded.',
        );
      case SwapStatus.txnLockupFailed:
        status = ('OldTransaction Lockup Failed', 'The swap will be refunded.');
      case SwapStatus.invoiceSet:
        status = (
          'OldInvoice Set',
          'The invoice for the swap has been set. Waiting for an onchain payment to be made. Swap will expire if an onchain payment is not made.',
        );
      case SwapStatus.invoicePending:
        status = (
          'OldInvoice Pending',
          'Onchain transaction confirmed. Payment of the invoice is in progress.',
        );
      case SwapStatus.invoicePaid:
        status = ('OldInvoice Paid', 'The invoice has been successfully paid.');
      case SwapStatus.invoiceFailedToPay:
        status = (
          'Failed to pay invoice',
          'The invoice has failed to pay. This transaction will be refunded.',
        );
      case SwapStatus.invoiceSettled:
        status = (
          'OldInvoice Settled',
          'The invoice has settled and the swap is completed.',
        );
      case SwapStatus.invoiceExpired:
        status = (
          'OldInvoice Expired',
          'The invoice has expirted. Swap will be deleted.',
        );
      case SwapStatus.minerfeePaid:
        status = ('Miner Fee Paid.', '');
      case SwapStatus.txnServerMempool:
        status = (
          'Boltz Mempool',
          'Boltz has made their payment. You can claim once this is confirmed',
        );
      case SwapStatus.txnServerConfirmed:
        status = (
          'Boltz Confirmed',
          'Boltz payment is confirmed. You can claim the onchain swap',
        );
      case null:
        return null;
      case SwapStatus.txnDirect:
        status = (
          'Direct Transaction',
          'A direct transaction has been made and the swap has been bypassed.',
        );
        throw UnimplementedError();
    }
    return status;
  }
}

extension LnSwapExt on OldSwapTx {
  BtcLnSwap toBtcLnSwap(OldLnSwapTxSensitive sensitive) {
    final tx = this;
    return BtcLnSwap(
      id: tx.id,
      invoice: tx.lnSwapDetails!.invoice,
      outAmount: BigInt.from(tx.outAmount),
      scriptAddress: tx.scriptAddress,
      electrumUrl: tx.lnSwapDetails!.electrumUrl.replaceAll('ssl://', ''),
      boltzUrl: tx.boltzUrl,
      kind: tx.lnSwapDetails!.swapType,
      keyIndex: BigInt.from(tx.lnSwapDetails!.keyIndex),
      network:
          network == OldBBNetwork.Testnet
              ? Chain.bitcoinTestnet
              : Chain.bitcoin,
      keys: KeyPair(
        secretKey: sensitive.secretKey,
        publicKey: sensitive.publicKey,
      ),
      preimage: PreImage(
        value: sensitive.preimage,
        sha256: sensitive.sha256,
        hash160: sensitive.hash160,
      ),
      swapScript: BtcSwapScriptStr(
        swapType: tx.lnSwapDetails!.swapType,
        hashlock: sensitive.hash160,
        receiverPubkey:
            tx.isSubmarine()
                ? tx.lnSwapDetails!.boltzPubKey
                : tx.lnSwapDetails!.myPublicKey,
        locktime: tx.lnSwapDetails!.locktime,
        senderPubkey:
            tx.isSubmarine()
                ? tx.lnSwapDetails!.myPublicKey
                : tx.lnSwapDetails!.boltzPubKey,
        fundingAddrs: tx.scriptAddress,
      ),
    );
  }

  LbtcLnSwap toLbtcLnSwap(OldLnSwapTxSensitive sensitive) {
    final tx = this;
    return LbtcLnSwap(
      id: tx.id,
      invoice: tx.lnSwapDetails!.invoice,
      outAmount: BigInt.from(tx.outAmount),
      scriptAddress: tx.scriptAddress,
      electrumUrl: tx.lnSwapDetails!.electrumUrl.replaceAll('ssl://', ''),
      boltzUrl: tx.boltzUrl,
      kind: tx.lnSwapDetails!.swapType,
      keyIndex: BigInt.from(tx.lnSwapDetails!.keyIndex),
      network:
          network == OldBBNetwork.Testnet ? Chain.liquidTestnet : Chain.liquid,
      keys: KeyPair(
        secretKey: sensitive.secretKey,
        publicKey: sensitive.publicKey,
      ),
      preimage: PreImage(
        value: sensitive.preimage,
        sha256: sensitive.sha256,
        hash160: sensitive.hash160,
      ),
      blindingKey: sensitive.blindingKey ?? '',
      swapScript: LBtcSwapScriptStr(
        swapType: tx.lnSwapDetails!.swapType,
        hashlock: sensitive.hash160,
        receiverPubkey:
            tx.isSubmarine()
                ? tx.lnSwapDetails!.boltzPubKey
                : tx.lnSwapDetails!.myPublicKey,
        locktime: tx.lnSwapDetails!.locktime,
        senderPubkey:
            tx.isSubmarine()
                ? tx.lnSwapDetails!.myPublicKey
                : tx.lnSwapDetails!.boltzPubKey,
        fundingAddrs: tx.scriptAddress,
        blindingKey: sensitive.blindingKey ?? '',
      ),
    );
  }
}

extension BtcLnSwapExt on BtcLnSwap {
  OldSwapTx createSwapFromBtcLnSwap() {
    return OldSwapTx(
      id: id,
      lnSwapDetails: OldLnSwapDetails(
        swapType: kind,
        invoice: invoice,
        boltzPubKey:
            kind == SwapType.submarine
                ? swapScript.receiverPubkey
                : swapScript.senderPubkey,
        keyIndex:
            0, // this is an issue, we should probably also save the keyIndex in BtcLnSwap
        myPublicKey:
            kind == SwapType.submarine
                ? swapScript.senderPubkey
                : swapScript.receiverPubkey,
        sha256: '',
        electrumUrl: electrumUrl,
        locktime: swapScript.locktime,
      ),
      // network: network == Chain.Testnet ? BBNetwork.Testnet : BBNetwork.LTestnet,
      network:
          network == Chain.liquidTestnet
              ? OldBBNetwork.Testnet
              : OldBBNetwork.Mainnet,
      walletType:
          (network == Chain.bitcoin || network == Chain.bitcoinTestnet)
              ? OldBaseWalletType.Bitcoin
              : OldBaseWalletType.Liquid,
      outAmount: outAmount.toInt(),
      scriptAddress: scriptAddress,
      boltzUrl: boltzUrl,
      creationTime: DateTime.now(),
    );
  }

  OldLnSwapTxSensitive createSwapSensitiveFromBtcLnSwap() {
    return OldLnSwapTxSensitive(
      id: id,
      preimage: preimage.value,
      sha256: preimage.sha256,
      hash160: preimage.hash160,
      publicKey: keys.publicKey,
      secretKey: keys.secretKey,
      boltzPubkey:
          kind == SwapType.submarine
              ? swapScript.receiverPubkey
              : swapScript.senderPubkey,
      locktime: swapScript.locktime,
      isSubmarine: kind == SwapType.submarine,
    );
  }
}

extension LbtcLnSwapExt on LbtcLnSwap {
  OldSwapTx createSwapFromLbtcLnSwap() {
    return OldSwapTx(
      id: id,
      lnSwapDetails: OldLnSwapDetails(
        swapType: kind,
        invoice: invoice,
        boltzPubKey:
            kind == SwapType.submarine
                ? swapScript.receiverPubkey
                : swapScript.senderPubkey,
        keyIndex:
            0, // this is an issue, we should probably also save the keyIndex in BtcLnSwap
        myPublicKey:
            kind == SwapType.submarine
                ? swapScript.senderPubkey
                : swapScript.receiverPubkey,
        sha256: '',
        electrumUrl: electrumUrl,
        locktime: swapScript.locktime,
        blindingKey: swapScript.blindingKey,
      ),
      // network: network == Chain.Testnet ? BBNetwork.Testnet : BBNetwork.LTestnet,
      network:
          network == Chain.liquidTestnet
              ? OldBBNetwork.Testnet
              : OldBBNetwork.Mainnet,
      walletType:
          (network == Chain.bitcoin || network == Chain.bitcoinTestnet)
              ? OldBaseWalletType.Bitcoin
              : OldBaseWalletType.Liquid,
      outAmount: outAmount.toInt(),
      scriptAddress: scriptAddress,
      boltzUrl: boltzUrl,
      creationTime: DateTime.now(),
    );
  }

  OldLnSwapTxSensitive createSwapSensitiveFromLbtcLnSwap() {
    return OldLnSwapTxSensitive(
      id: id,
      preimage: preimage.value,
      sha256: preimage.sha256,
      hash160: preimage.hash160,
      publicKey: keys.publicKey,
      secretKey: keys.secretKey,
      blindingKey: blindingKey,
      boltzPubkey:
          kind == SwapType.submarine
              ? swapScript.receiverPubkey
              : swapScript.senderPubkey,
      locktime: swapScript.locktime,
      isSubmarine: kind == SwapType.submarine,
    );
  }
}

extension ChSwapExt on OldSwapTx {
  ChainSwap toChainSwap(OldChainSwapTxSensitive sensitive) {
    return ChainSwap(
      id: id,
      isTestnet: network == OldBBNetwork.Testnet, // TODO:onChain
      direction: chainSwapDetails!.direction,
      refundKeys: KeyPair(
        publicKey: chainSwapDetails!.refundPublicKey,
        secretKey: sensitive.refundKeySecret,
      ),
      refundIndex: BigInt.from(chainSwapDetails!.refundKeyIndex),
      claimKeys: KeyPair(
        publicKey: chainSwapDetails!.claimPublicKey,
        secretKey: sensitive.claimKeySecret,
      ),
      claimIndex: BigInt.from(chainSwapDetails!.claimKeyIndex),
      preimage: PreImage(
        value: sensitive.preimage,
        sha256: sensitive.sha256,
        hash160: sensitive.hash160,
      ),
      btcScriptStr: BtcSwapScriptStr(
        swapType: SwapType.chain,
        hashlock: sensitive.hash160,
        fundingAddrs: chainSwapDetails!.btcFundingAddress,
        receiverPubkey: chainSwapDetails!.btcScriptReceiverPublicKey,
        locktime:
            chainSwapDetails!.direction == ChainSwapDirection.btcToLbtc
                ? chainSwapDetails!.lockupLocktime
                : chainSwapDetails!.claimLocktime,
        senderPubkey: chainSwapDetails!.btcScriptSenderPublicKey,
        side:
            chainSwapDetails!.direction == ChainSwapDirection.btcToLbtc
                ? Side.lockup
                : Side.claim,
      ),
      lbtcScriptStr: LBtcSwapScriptStr(
        swapType: SwapType.chain,
        hashlock: sensitive.hash160,
        fundingAddrs: chainSwapDetails!.lbtcFundingAddress,
        receiverPubkey: chainSwapDetails!.lbtcScriptReceiverPublicKey,
        locktime:
            chainSwapDetails!.direction == ChainSwapDirection.lbtcToBtc
                ? chainSwapDetails!.lockupLocktime
                : chainSwapDetails!.claimLocktime,
        senderPubkey: chainSwapDetails!.lbtcScriptSenderPublicKey,
        blindingKey: sensitive.blindingKey,
        side:
            chainSwapDetails!.direction == ChainSwapDirection.lbtcToBtc
                ? Side.lockup
                : Side.claim,
      ),
      scriptAddress: scriptAddress,
      outAmount: BigInt.from(outAmount),
      btcElectrumUrl: chainSwapDetails!.btcElectrumUrl,
      lbtcElectrumUrl: chainSwapDetails!.lbtcElectrumUrl,
      boltzUrl: boltzUrl,
      blindingKey: sensitive.blindingKey,
    );
  }
}

extension ChainSwapExt on ChainSwap {
  OldSwapTx createSwapFromChainSwap(
    String toWalletId,
    OldOnChainSwapType onChainSwapType,
  ) {
    return OldSwapTx(
      id: id,
      chainSwapDetails: OldChainSwapDetails(
        onChainType: onChainSwapType,
        direction: direction,
        refundKeyIndex: refundIndex.toInt(),
        claimKeyIndex: claimIndex.toInt(),
        refundPublicKey: refundKeys.publicKey,
        refundSecretKey: refundKeys.secretKey,
        claimPublicKey: claimKeys.publicKey,
        claimSecretKey: claimKeys.secretKey,
        lockupLocktime:
            direction == ChainSwapDirection.btcToLbtc
                ? btcScriptStr.locktime
                : lbtcScriptStr.locktime,
        claimLocktime:
            direction == ChainSwapDirection.lbtcToBtc
                ? btcScriptStr.locktime
                : lbtcScriptStr.locktime,
        blindingKey: blindingKey,
        btcElectrumUrl: btcElectrumUrl,
        // 'electrum.blockstream.info:60002', // btcElectrumUrl, // TODO:chainswap // TODO:Onchain
        lbtcElectrumUrl: lbtcElectrumUrl,
        btcFundingAddress: btcScriptStr.fundingAddrs ?? '',
        btcScriptReceiverPublicKey: btcScriptStr.receiverPubkey,
        btcScriptSenderPublicKey: btcScriptStr.senderPubkey,
        lbtcFundingAddress: lbtcScriptStr.fundingAddrs ?? '',
        lbtcScriptReceiverPublicKey: lbtcScriptStr.receiverPubkey,
        lbtcScriptSenderPublicKey: lbtcScriptStr.senderPubkey,
        toWalletId: toWalletId,
      ),
      network: isTestnet ? OldBBNetwork.Testnet : OldBBNetwork.Mainnet,
      walletType:
          direction == ChainSwapDirection.btcToLbtc
              ? OldBaseWalletType.Bitcoin
              : OldBaseWalletType.Liquid,
      outAmount: outAmount.toInt(),
      scriptAddress: scriptAddress,
      boltzUrl: boltzUrl,
      creationTime: DateTime.now(),
    );
  }

  OldChainSwapTxSensitive createSwapSensitiveFromChainSwap() {
    return OldChainSwapTxSensitive(
      id: id,
      refundKeySecret: refundKeys.secretKey,
      claimKeySecret: claimKeys.secretKey,
      preimage: preimage.value,
      sha256: preimage.sha256,
      hash160: preimage.hash160,
      blindingKey: blindingKey,
    );
  }
}
