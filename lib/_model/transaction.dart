// ignore_for_file: invalid_annotation_target

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:boltz_dart/boltz_dart.dart' as boltz;
import 'package:boltz_dart/boltz_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:timeago/timeago.dart' as timeago;

part 'transaction.freezed.dart';
part 'transaction.g.dart';

@freezed
class Transaction with _$Transaction {
  const factory Transaction({
    required int timestamp,
    required String txid,
    int? received,
    int? sent,
    int? fee,
    double? feeRate,
    int? height,
    String? label,
    String? toAddress,
    String? psbt,
    @JsonKey(
      includeFromJson: false,
      includeToJson: false,
    )
    Uint8List? pset,
    @Default(true) bool rbfEnabled,
    // @Default(false) bool oldTx,
    int? broadcastTime,
    // String? serializedTx,
    @Default([]) List<Address> outAddrs,
    @Default([]) List<TxIn> inputs,
    @JsonKey(
      includeFromJson: false,
      includeToJson: false,
    )
    bdk.TransactionDetails? bdkTx,
    // Wallet? wallet,
    @Default(false) bool isSwap,
    SwapTx? swapTx,
    @Default(false) bool isLiquid,
    @Default('') String unblindedUrl,
    @Default([]) List<String> rbfTxIds,
    String? walletId,
  }) = _Transaction;
  const Transaction._();

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);

  factory Transaction.fromSwapTx(SwapTx swapTx) {
    return Transaction(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      txid: swapTx.id,
      swapTx: swapTx,
      isSwap: true,
    );
  }

  bool swapIdisTxid() => swapTx != null && swapTx!.id == txid;

  Uint8List? get psbtAsBytes =>
      psbt == null ? null : Uint8List.fromList(psbt!.codeUnits);

  Address? mapOutValueToAddress(int value) {
    if (outAddrs.isEmpty) return null;
    try {
      final Address address = outAddrs.firstWhere(
        (element) => element.highestPreviousBalance == value,
      );
      return address;
    } catch (e) {
      return null;
    }
  }

  List<Address> createOutAddrsFromTx() {
    final List<Address> outAddrs = [];
    return outAddrs;
  }

  bool isReceived() =>
      sent == 0 || sent != null && received != null && received! > sent!;

  bool isReceivedCatchSelfPayment() =>
      sent == 0 || sent != null && received != null && received! > sent!;

  bool isToSelf() {
    if (!isReceived()) {
      final index = outAddrs.indexWhere(
        (element) => element.kind == AddressKind.deposit,
      );
      if (index == -1)
        return false;
      else
        return true;
    } else
      return false;
  }

  int getAmount({bool sentAsTotal = false}) {
    try {
      return isReceived()
          ? received!
          : sentAsTotal
              ? (sent! - received!)
              : (sent! - received! - fee!);
    } catch (e) {
      return 0;
    }
  }

  // int getAmount({bool sentAsTotal = false}) => isReceived()
  //     ? (received! - fee!)
  //     : sentAsTotal
  //         ? sent!
  //         : (sent! - fee!);

  DateTime getDateTime() {
    return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  }

  static const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sept',
    'Oct',
    'Nov',
    'Dec',
  ];

  String getDateTimeStr() {
    if (timestamp == 0) return '';
    // final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    var dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (dt.year == 1970) {
      dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    }
    if (dt.isAfter(DateTime.now().subtract(const Duration(days: 2))))
      return timeago.format(dt);
    final day =
        dt.day.toString().length == 1 ? '0${dt.day}' : dt.day.toString();
    return months[dt.month - 1] + ' ' + day + ', ' + dt.year.toString();
  }

  DateTime? getBroadcastDateTime() => broadcastTime == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(broadcastTime!);

  // bool canRBF() => rbfEnabled == true && timestamp == 0;
  // TODO: New code: Yet to check
  bool canRBF() => rbfEnabled == true && (height == null || height! == 0);

  bool isConfirmed() => timestamp != 0 || height != null || height! > 0;

  bool isPending() => timestamp == 0 || height == null || height! == 0;
}

DateTime getDateTimeFromInt(int time) =>
    DateTime.fromMillisecondsSinceEpoch(time * 1000);

class SerializedTx {
  SerializedTx({this.version, this.lockTime, this.input, this.output});

  factory SerializedTx.fromJson(Map<String, dynamic> json) {
    return SerializedTx(
      version: json['version'] as int?,
      lockTime: json['lock_time'] as int?,
      input: (json['input'] as List?)
          ?.map((e) => Input.fromJson(e as Map<String, dynamic>))
          .toList(),
      output: (json['output'] as List?)
          ?.map((e) => Output.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
  int? version;
  int? lockTime;
  List<Input>? input;
  List<Output>? output;
}

@freezed
class TxIn with _$TxIn {
  const factory TxIn({
    required String prevOut, // as txid:index
  }) = _TxIn;
  const TxIn._();

  factory TxIn.fromJson(Map<String, dynamic> json) => _$TxInFromJson(json);
}

class Input {
  Input({this.previousOutput, this.scriptSig, this.sequence, this.witness});

  factory Input.fromJson(Map<String, dynamic> json) {
    return Input(
      previousOutput: json['previous_output'] as String?,
      scriptSig: json['script_sig'] as String?,
      sequence: json['sequence'] as int?,
      witness: (json['witness'] as List?)?.map((e) => e as String).toList(),
    );
  }
  String? previousOutput;
  String? scriptSig;
  int? sequence;
  List<String>? witness;
}

class Output {
  Output({this.value, this.scriptPubkey});

  factory Output.fromJson(Map<String, dynamic> json) {
    return Output(
      value: json['value'] as int?,
      scriptPubkey: json['script_pubkey'] as String?,
    );
  }
  int? value;
  String? scriptPubkey;
}

@freezed
class ChainSwapDetails with _$ChainSwapDetails {
  const factory ChainSwapDetails({
    required ChainSwapDirection direction,
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
    required BaseWalletType baseWalletType,
    required int outAmount,
    required String scriptAddress,
    required String boltzUrl,
    ChainSwapDetails? chainSwapDetails,
    LnSwapDetails? lnSwapDetails,
    String? txid,
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

  const SwapTx._();

  factory SwapTx.fromJson(Map<String, dynamic> json) => _$SwapTxFromJson(json);

  bool isTestnet() => network == BBNetwork.Testnet;

  bool isLiquid() => baseWalletType == BaseWalletType.Liquid;

  int? totalFees() {
    if (boltzFees == null || lockupFees == null || claimFees == null)
      return null;

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
              status!.status == SwapStatus.txnLockupFailed));

  bool refundedAny() =>
      status != null &&
      (status!.status == SwapStatus.swapRefunded ||
          status!.status == SwapStatus.txnRefunded);

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
          (status!.status == SwapStatus.invoiceSettled && txid == null));

  bool expiredReverse() =>
      isReverse() &&
      (status != null &&
          (status!.status == SwapStatus.invoiceExpired ||
              status!.status == SwapStatus.swapExpired));

  bool settledReverse() =>
      isReverse() &&
      txid != null &&
      (status != null && (status!.status == SwapStatus.invoiceSettled));

  bool paidReverse() =>
      isReverse() &&
      (status != null && (status!.status == SwapStatus.txnMempool));

  bool paidOnchain() =>
      isChainSwap() &&
      // txid != null &&
      (status != null &&
          (status!.status == SwapStatus.txnMempool ||
              status!.status == SwapStatus.txnConfirmed ||
              status!.status == SwapStatus.txnServerMempool ||
              status!.status == SwapStatus.txnServerConfirmed));

  bool claimedOnchain() =>
      isChainSwap() &&
      // txid != null &&
      (status != null && (status!.status == SwapStatus.txnClaimed));

  bool expiredOnchain() =>
      isChainSwap() &&
      // txid != null &&
      (status != null && (status!.status == SwapStatus.swapExpired));

  bool uninitiatedOnchain() =>
      isChainSwap() &&
      creationTime!.difference(DateTime.now()).inDays > 3 &&
      (status != null && (status!.status == SwapStatus.swapCreated));

  bool receiveAction() => settledReverse() || paidReverse();

  bool proceesTx() =>
      paidSubmarine() ||
      settledReverse() ||
      settledSubmarine() ||
      paidReverse();

  bool close() =>
      settledReverse() ||
      settledSubmarine() ||
      expiredReverse() ||
      expiredSubmarine() ||
      refundedAny() ||
      claimedOnchain() ||
      expiredOnchain() ||
      uninitiatedOnchain();

  bool failed() => isChainSwap()
      ? chainSwapAction()
      : isReverse()
          ? reverseSwapAction() == ReverseSwapActions.failed
          : submarineSwapAction() == SubmarineSwapActions.failed;

  //TODO:Onchain
  bool chainSwapAction() {
    return status?.status == boltz.SwapStatus.txnFailed;
  }

  String splitInvoice() =>
      lnSwapDetails!.invoice.substring(0, 5) +
      ' .... ' +
      lnSwapDetails!.invoice.substring(lnSwapDetails!.invoice.length - 10);

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

    if (statuss == null || statuss == SwapStatus.swapCreated)
      return ReverseSwapActions.created;
    else if (expiredReverse() ||
        statuss == SwapStatus.swapError ||
        statuss == SwapStatus.txnFailed ||
        statuss == SwapStatus.txnLockupFailed)
      return ReverseSwapActions.failed;
    else if (paidReverse())
      return ReverseSwapActions.paid;
    else if (claimableReverse())
      return ReverseSwapActions.claimable;
    else if (settledReverse())
      return ReverseSwapActions.settled;
    else
      return ReverseSwapActions.created;
  }

  SubmarineSwapActions submarineSwapAction() {
    if (!isSubmarine()) throw 'Swap is not submarine!';
    final statuss = status?.status;

    if (statuss == null || statuss == SwapStatus.swapCreated)
      return SubmarineSwapActions.created;
    else if (expiredSubmarine() ||
        statuss == SwapStatus.swapExpired ||
        statuss == SwapStatus.swapError ||
        statuss == SwapStatus.txnFailed)
      return SubmarineSwapActions.failed;
    else if (paidSubmarine())
      return SubmarineSwapActions.paid;
    else if (claimableSubmarine())
      return SubmarineSwapActions.claimable;
    else if (settledSubmarine())
      return SubmarineSwapActions.settled;
    else if (refundableSubmarine())
      return SubmarineSwapActions.refundable;
    else
      return SubmarineSwapActions.created;
  }

  bool showAlert() {
    if (isChainSwap()) {
      if (paidOnchain() || claimedOnchain()) return true;
    } else if (isSubmarine()) {
      if (paidSubmarine() || settledSubmarine()) return true;
    } else {
      if (paidReverse() || settledReverse()) return true;
    }
    return false;
  }

  bool syncWallet() {
    if (isSubmarine()) {
      if (claimableSubmarine() || refundableSubmarine() || settledSubmarine())
        return true;
    } else {
      if (claimableReverse() || settledReverse()) return true;
    }
    return false;
  }

  Transaction toNewTransaction() {
    final newTx = Transaction(
      txid: txid ?? id,
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
      msats: decodedInvoice.msats,
      expiry: decodedInvoice.expiry,
      expiresIn: decodedInvoice.expiresIn,
      expiresAt: decodedInvoice.expiresAt,
      isExpired: decodedInvoice.isExpired,
      network: decodedInvoice.network,
      cltvExpDelta: decodedInvoice.cltvExpDelta,
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

extension X on boltz.SwapStatus? {
  (String, String)? getOnChainStr() {
    (String, String) status = ('', '');
    switch (this) {
      case boltz.SwapStatus.swapCreated:
        status =
            ('Created', 'Swap has been created but no payment has been made.');
      case boltz.SwapStatus.swapExpired:
        status = ('Expired', 'Swap has expired');
      case boltz.SwapStatus.swapRefunded:
        status = ('Refunded', 'Swap has been successfully refunded');
      case boltz.SwapStatus.swapError:
        status = ('Error', 'Swap was unsuccessful');
      case boltz.SwapStatus.txnMempool:
        status = (
          'Mempool',
          'You have paid the swap lockup transaction. Waiting for block confirmation'
        );

      /// TODO: This happens with onchain swap?
      case boltz.SwapStatus.txnClaimPending:
        status = (
          'Claim Pending',
          'The lightning invoice has been paid. Waiting for boltz to complete the swap.'
        );
      case boltz.SwapStatus.txnClaimed:
        status = ('Claimed', 'The swap is completed.');
      case boltz.SwapStatus.txnConfirmed:
        status = (
          'Confirmed',
          'Your lockup transaction is confirmed. Waiting for Boltz lockup'
        );
      case boltz.SwapStatus.txnRefunded:
        status = ('Refunded', 'The swap has been successfully refunded.');
      case boltz.SwapStatus.txnFailed:
        status = ('Transaction Failed', 'The swap will be refunded.');
      case boltz.SwapStatus.txnLockupFailed:
        status = ('Transaction Lockup Failed', 'The swap will be refunded.');

      /// TODO: This happens with onchain swap?
      case boltz.SwapStatus.invoiceSet:
        status = ('Invoice Set', 'The invoice for the swap has been set.');

      /// TODO: This happens with onchain swap?
      case boltz.SwapStatus.invoicePending:
        status = (
          'Invoice Pending',
          'Onchain transaction confirmed. Payment of the invoice is in progress.'
        );

      /// TODO: This happens with onchain swap?
      case boltz.SwapStatus.invoicePaid:
        status = ('Invoice Paid', 'The invoice has been successfully paid.');

      /// TODO: This happens with onchain swap?
      case boltz.SwapStatus.invoiceFailedToPay:
        status = (
          'Failed to pay invoice',
          'The invoice has failed to pay. This transaction will be refunded.'
        );

      /// TODO: This happens with onchain swap?
      case boltz.SwapStatus.invoiceSettled:
        status = (
          'Invoice Settled',
          'The invoice has settled and the swap is completed.'
        );

      /// TODO: This happens with onchain swap?
      case boltz.SwapStatus.invoiceExpired:
        status = (
          'Invoice Expired',
          'The invoice has expirted. Swap will be deleted.'
        );

      /// TODO: This happens with onchain swap?
      case boltz.SwapStatus.minerfeePaid:
        status = ('Miner Fee Paid.', '');
      case boltz.SwapStatus.txnServerMempool:
        status = (
          'Boltz Mempool',
          'Boltz has made thier payment. You can claim once this is confirmed'
        );
      case boltz.SwapStatus.txnServerConfirmed:
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
      case boltz.SwapStatus.swapCreated:
        status =
            ('Created', 'Swap has been created but no payment has been made.');
      case boltz.SwapStatus.swapExpired:
        status = ('Expired', 'Swap has expired');
      case boltz.SwapStatus.swapRefunded:
        status = ('Refunded', 'Swap has been successfully refunded');
      case boltz.SwapStatus.swapError:
        status = ('Error', 'Swap was unsuccessful');
      case boltz.SwapStatus.txnMempool:
        status = (
          'Mempool',
          isSubmarine
              ? 'You have paid the swap lockup transaction. The invoice will be paid as soon as the transaction is confirmed.'
              : 'Sender has paid the invoice and Boltz has made the lockup transaction. You will be able to claim it as soon as the transaction is confirmed.'
        );
      case boltz.SwapStatus.txnClaimPending:
        status = (
          'Claim Pending',
          'The lightning invoice has been paid. Waiting for boltz to complete the swap.'
        );
      case boltz.SwapStatus.txnClaimed:
        status = ('Claimed', 'The swap is completed.');
      case boltz.SwapStatus.txnConfirmed:
        status = (
          'Confirmed',
          isSubmarine
              ? 'Your lockup transaction is confirmed. The invoice will be paid momentarily.'
              : 'Boltz lockup transaction is confirmed. The swap will be claimed and you will recieve funds after the claim transaction gets confirmed.'
        );
      case boltz.SwapStatus.txnRefunded:
        status = ('Refunded', 'The swap has been successfully refunded.');
      case boltz.SwapStatus.txnFailed:
        status = ('Transaction Failed', 'The swap will be refunded.');
      case boltz.SwapStatus.txnLockupFailed:
        status = ('Transaction Lockup Failed', 'The swap will be refunded.');
      case boltz.SwapStatus.invoiceSet:
        status = (
          'Invoice Set',
          'The invoice for the swap has been set. Waiting for an onchain payment to be made. Swap will expire if an onchain payment is not made.'
        );
      case boltz.SwapStatus.invoicePending:
        status = (
          'Invoice Pending',
          'Onchain transaction confirmed. Payment of the invoice is in progress.'
        );
      case boltz.SwapStatus.invoicePaid:
        status = ('Invoice Paid', 'The invoice has been successfully paid.');
      case boltz.SwapStatus.invoiceFailedToPay:
        status = (
          'Failed to pay invoice',
          'The invoice has failed to pay. This transaction will be refunded.'
        );
      case boltz.SwapStatus.invoiceSettled:
        status = (
          'Invoice Settled',
          'The invoice has settled and the swap is completed.'
        );
      case boltz.SwapStatus.invoiceExpired:
        status = (
          'Invoice Expired',
          'The invoice has expirted. Swap will be deleted.'
        );
      case boltz.SwapStatus.minerfeePaid:
        status = ('Miner Fee Paid.', '');
      case boltz.SwapStatus.txnServerMempool:
        status = (
          'Boltz Mempool',
          'Boltz has made thier payment. You can claim once this is confirmed'
        );
      case boltz.SwapStatus.txnServerConfirmed:
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
