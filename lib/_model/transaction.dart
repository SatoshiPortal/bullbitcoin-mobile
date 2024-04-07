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
  }) = _Transaction;
  const Transaction._();

  factory Transaction.fromJson(Map<String, dynamic> json) => _$TransactionFromJson(json);

  factory Transaction.fromSwapTx(SwapTx swapTx) {
    return Transaction(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      txid: swapTx.id,
      swapTx: swapTx,
      isSwap: true,
    );
  }

  Uint8List? get psbtAsBytes => psbt == null ? null : Uint8List.fromList(psbt!.codeUnits);

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

  bool isReceived() => sent == 0 || sent != null && received != null && received! > sent!;

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
    // final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    var dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (dt.year == 1970) {
      dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    }
    if (dt.isAfter(DateTime.now().subtract(const Duration(days: 2)))) return timeago.format(dt);
    final day = dt.day.toString().length == 1 ? '0${dt.day}' : dt.day.toString();
    return months[dt.month - 1] + ' ' + day + ', ' + dt.year.toString();
  }

  DateTime? getBroadcastDateTime() =>
      broadcastTime == null ? null : DateTime.fromMillisecondsSinceEpoch(broadcastTime!);

  bool canRBF() => rbfEnabled == true && timestamp == 0;
}

DateTime getDateTimeFromInt(int time) => DateTime.fromMillisecondsSinceEpoch(time * 1000);

class SerializedTx {
  SerializedTx({this.version, this.lockTime, this.input, this.output});

  factory SerializedTx.fromJson(Map<String, dynamic> json) {
    return SerializedTx(
      version: json['version'] as int?,
      lockTime: json['lock_time'] as int?,
      input:
          (json['input'] as List?)?.map((e) => Input.fromJson(e as Map<String, dynamic>)).toList(),
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
    String? secretKey,
    String? publicKey,
    String? sha256,
    String? hash160,
    required String redeemScript,
    required String invoice,
    required int outAmount,
    required String scriptAddress,
    required String electrumUrl,
    required String boltzUrl,
    SwapStatusResponse? status, // should this be SwapStaus?
    String? blindingKey, // sensitive
    int? boltzFees,
    int? lockupFees,
    int? claimFees,
  }) = _SwapTx;

  factory SwapTx.fromBtcLnSwap(BtcLnBoltzSwap result) {
    final swap = result.btcLnSwap;
    return SwapTx(
      id: swap.id,
      isSubmarine: swap.kind == SwapType.Submarine,
      network: swap.network == Chain.Testnet ? BBNetwork.Testnet : BBNetwork.LTestnet,
      redeemScript: swap.redeemScript,
      invoice: swap.invoice,
      outAmount: swap.outAmount,
      scriptAddress: swap.scriptAddress,
      electrumUrl: swap.electrumUrl,
      boltzUrl: swap.boltzUrl,
    );
  }
  const SwapTx._();

  factory SwapTx.fromJson(Map<String, dynamic> json) => _$SwapTxFromJson(json);

  int? totalFees() {
    if (boltzFees == null || lockupFees == null || claimFees == null) return null;

    return boltzFees! + lockupFees! + claimFees!;
  }

  int? recievableAmount() {
    if (totalFees() == null) return null;
    return outAmount - totalFees()!;
  }

  bool get paidSubmarine =>
      isSubmarine &&
      (status != null &&
          (status!.status == SwapStatus.txnMempool || status!.status == SwapStatus.txnConfirmed));

  bool get settledSubmarine =>
      isSubmarine && (status != null && (status!.status == SwapStatus.txnClaimed));

  bool get refundableSubmarine =>
      isSubmarine && (status != null && (status!.status == SwapStatus.invoiceFailedToPay));

  bool get claimableReverse =>
      !isSubmarine &&
      status != null &&
      (status!.status == SwapStatus.txnMempool || status!.status == SwapStatus.txnConfirmed);

  bool get settledReverse =>
      !isSubmarine && (status != null && (status!.status == SwapStatus.invoiceSettled));

  bool get expiredReverse =>
      !isSubmarine &&
      (status != null &&
          (status!.status == SwapStatus.invoiceExpired ||
              status!.status == SwapStatus.swapExpired));

  BtcLnBoltzSwap toBtcLnSwap(SwapTxSensitive sensitive) {
    final tx = this;
    return BtcLnBoltzSwap(
      BtcLnSwap(
        id: tx.id,
        redeemScript: tx.redeemScript,
        invoice: tx.invoice,
        outAmount: tx.outAmount,
        scriptAddress: tx.scriptAddress,
        electrumUrl: tx.electrumUrl.replaceAll('ssl://', ''),
        boltzUrl: tx.boltzUrl,
        kind: SwapType.Reverse,
        network: Chain.Testnet,
        keys: KeyPair(
          secretKey: sensitive.secretKey,
          publicKey: sensitive.publicKey,
        ),
        preimage: PreImage(
          value: sensitive.value,
          sha256: sensitive.sha256,
          hash160: sensitive.hash160,
        ),
      ),
    );
  }

  String splitInvoice() =>
      invoice.substring(0, 5) + ' .... ' + invoice.substring(invoice.length - 10);
}

extension SwapTxExt on SwapStatus {
  bool get showPending => this == SwapStatus.invoicePaid;
  bool get showQR => this != SwapStatus.invoiceSettled || hasExpired;
  bool get hasExpired => this == SwapStatus.swapExpired || this == SwapStatus.invoiceExpired;
  bool get reverseSettled => this == SwapStatus.invoiceSettled;
}

@freezed
class SwapTxSensitive with _$SwapTxSensitive {
  const factory SwapTxSensitive.SwapTxSensitive({
    required String id,
    required String secretKey,
    required String publicKey,
    required String value,
    required String sha256,
    required String hash160,
  }) = _SwapTxSensitive;
  const SwapTxSensitive._();

  factory SwapTxSensitive.fromBtcLnSwap(BtcLnBoltzSwap result) {
    final swap = result.btcLnSwap;
    return SwapTxSensitive.SwapTxSensitive(
      id: swap.id,
      value: swap.preimage.value,
      sha256: swap.preimage.sha256,
      hash160: swap.preimage.hash160,
      publicKey: swap.keys.publicKey,
      secretKey: swap.keys.secretKey,
    );
  }

  factory SwapTxSensitive.fromJson(Map<String, dynamic> json) => _$SwapTxSensitiveFromJson(json);
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
  }) = _Invoice;
  const Invoice._();

  factory Invoice.fromJson(Map<String, dynamic> json) => _$InvoiceFromJson(json);

  factory Invoice.fromDecodedInvoice(DecodedInvoice decodedInvoice, String invoice) {
    return Invoice(
      invoice: invoice,
      msats: decodedInvoice.msats,
      expiry: decodedInvoice.expiry,
      expiresIn: decodedInvoice.expiresIn,
      expiresAt: decodedInvoice.expiresAt,
      isExpired: decodedInvoice.isExpired,
      network: decodedInvoice.network,
      cltvExpDelta: decodedInvoice.cltvExpDelta,
    );
  }

  int getAmount() => msats ~/ 1000;
}


// String swapStatusToString(SwapStatus swap) {
//   debugPrint('swapToJson');
//   final value = swap.toJson();
//   return value;
// }

// SwapStatus? _addSwapStatus(Map<String, dynamic> json) {
//   if (!json.containsKey('statusStr') || !json.containsValue('statusStr')) return null;

//   final value = getSwapStatusFromString(json['statusStr'] as String);
//   return value;
// }
