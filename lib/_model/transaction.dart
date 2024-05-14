// ignore_for_file: invalid_annotation_target

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
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
    @Default(false) bool oldTx,
    int? broadcastTime,
    // String? serializedTx,
    @Default([]) List<Address> outAddrs,
    @JsonKey(
      includeFromJson: false,
      includeToJson: false,
    )
    bdk.TransactionDetails? bdkTx,
    Wallet? wallet,
    @Default(false) bool isSwap,
    SwapTx? swapTx,
    @Default(false) bool isLiquid,
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

  bool canRBF() => rbfEnabled == true && timestamp == 0;
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
class SwapTx with _$SwapTx {
  const factory SwapTx({
    required String id,
    String? txid,
    int? keyIndex,
    required bool isSubmarine,
    required BBNetwork network,
    required BaseWalletType walletType,
    String? secretKey,
    String? publicKey,
    String? sha256,
    String? hash160,
    required String redeemScript,
    String? boltzPubkey,
    int? locktime,
    required String invoice,
    required int outAmount,
    required String scriptAddress,
    required String electrumUrl,
    required String boltzUrl,
    SwapStreamStatus? status, // should this be SwapStaus?
    String? blindingKey, // sensitive
    int? boltzFees,
    int? lockupFees,
    int? claimFees,
    String? claimAddress,
  }) = _SwapTx;

  const SwapTx._();

  factory SwapTx.fromJson(Map<String, dynamic> json) => _$SwapTxFromJson(json);

  bool isLiquid() => walletType == BaseWalletType.Liquid;

  int? totalFees() {
    if (boltzFees == null || lockupFees == null || claimFees == null)
      return null;

    return boltzFees! + lockupFees! + claimFees!;
  }

  int? recievableAmount() {
    if (totalFees() == null) return null;
    return outAmount - totalFees()!;
  }

  bool paidSubmarine() =>
      isSubmarine &&
      (status != null && (status!.status == SwapStatus.txnMempool));

  bool settledSubmarine() =>
      isSubmarine &&
      (status != null && (status!.status == SwapStatus.txnClaimed));

  bool refundableSubmarine() =>
      isSubmarine &&
      (status != null &&
          (status!.status == SwapStatus.invoiceFailedToPay ||
              status!.status == SwapStatus.txnLockupFailed));

  bool claimableSubmarine() =>
      isSubmarine &&
      status != null &&
      (status!.status == SwapStatus.txnClaimPending ||
          status!.status == SwapStatus.txnConfirmed);

  bool claimableReverse() =>
      !isSubmarine &&
      status != null &&
      (status!.status == SwapStatus.txnConfirmed);

  bool expiredReverse() =>
      !isSubmarine &&
      (status != null &&
          (status!.status == SwapStatus.invoiceExpired ||
              status!.status == SwapStatus.swapExpired));

  bool expiredSubmarine() =>
      isSubmarine &&
      (status != null && (status!.status == SwapStatus.swapExpired));

  bool settledReverse() =>
      !isSubmarine &&
      (status != null && (status!.status == SwapStatus.invoiceSettled));

  bool paidReverse() =>
      !isSubmarine &&
      (status != null && (status!.status == SwapStatus.txnMempool));

  bool receiveAction() => settledReverse() || paidReverse();

  bool proceesTx() =>
      paidSubmarine() ||
      settledReverse() ||
      settledSubmarine() ||
      paidReverse();

  bool close() => settledReverse() || settledSubmarine() || expiredReverse();

  bool failed() => !isSubmarine
      ? reverseSwapAction() == ReverseSwapActions.failed
      : submarineSwapAction() == SubmarineSwapActions.failed;

  String splitInvoice() =>
      invoice.substring(0, 5) +
      ' .... ' +
      invoice.substring(invoice.length - 10);

  bool smallAmt() => outAmount < 1000000;

  double? highFees() {
    final fee = totalFees();
    if (fee == null) return null;
    final feesPercent = (fee / outAmount) * 100;
    if (feesPercent > 3) return feesPercent;
    return null;
  }

  String actionPrefixStr() {
    if (isSubmarine) {
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
    if (isSubmarine) throw 'Submarine swap cannot be a reverse swap.';
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
    if (!isSubmarine) throw 'Reverse swap cannot be a submarine swap.';
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
class SwapTxSensitive with _$SwapTxSensitive {
  const factory SwapTxSensitive({
    required String id,
    required String secretKey,
    required String publicKey,
    required String preimage,
    required String sha256,
    required String hash160,
    required String redeemScript,
    String? boltzPubkey,
    bool? isSubmarine,
    String? scriptAddress,
    int? locktime,
    String? blindingKey,
  }) = _SwapTxSensitive;
  const SwapTxSensitive._();

  factory SwapTxSensitive.fromJson(Map<String, dynamic> json) =>
      _$SwapTxSensitiveFromJson(json);
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
