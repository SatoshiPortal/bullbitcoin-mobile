// ignore_for_file: invalid_annotation_target

import 'dart:ui';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/styles.dart';
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
    // lockup submarine + claim reverse + lockup chain.send + lockup chain.self
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

  factory Transaction.fromSwapTx(SwapTx swapTx) {
    return Transaction(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      txid: swapTx.id,
      swapTx: swapTx,
      isSwap: true,
    );
  }
  const Transaction._();

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);

  (String, Color) buildTagDetails() {
    final hasSwap = swapTx != null;

    Color colour;
    String text;

    final isChainSwap = isSwap && swapTx!.isChainSwap();
    final isChainSend = isSwap && swapTx!.isChainSend();
    final isChainReceive = isSwap && swapTx!.isChainReceive();
    if (hasSwap) {
      if (isChainSwap == true) {
        final isBtcToLbtc =
            swapTx?.chainSwapDetails?.direction == ChainSwapDirection.btcToLbtc;
        if (isChainReceive) {
          text = isBtcToLbtc ? 'Bitcoin' : 'Liquid';
        } else if (isChainSend) {
          text = isBtcToLbtc ? 'Liquid' : 'Bitcoin';
        } else {
          text = isBtcToLbtc ? 'BTC -> LBTC' : 'LBTC -> BTC ';
        }
      } else {
        text = 'Lightning';
      }
    } else if (isLiquid) {
      text = 'Liquid on-chain';
    } else {
      text = 'Bitcoin on-chain';
    }

    if (isChainSwap) {
      if (isChainSend) {
        colour = isLiquid ? CardColours.yellow : CardColours.orange;
      } else if (isChainReceive) {
        colour = !isLiquid ? CardColours.yellow : CardColours.orange;
      } else {
        // self swap we tag with the receiving wallet
        colour = !isLiquid ? CardColours.yellow : CardColours.orange;
      }
    } else {
      colour = isLiquid ? CardColours.yellow : CardColours.orange;
    }

    return (text, colour);
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
      if (index == -1) {
        return false;
      } else {
        return true;
      }
    } else {
      return false;
    }
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
    if (timestamp == 0) return 'Pending';
    // final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    var dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (dt.year == 1970) {
      dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    }
    if (dt.isAfter(DateTime.now().subtract(const Duration(days: 2)))) {
      return timeago.format(dt);
    }
    final day =
        dt.day.toString().length == 1 ? '0${dt.day}' : dt.day.toString();
    return '${months[dt.month - 1]} $day, ${dt.year}';
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
