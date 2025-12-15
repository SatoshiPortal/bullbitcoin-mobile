// ignore_for_file: invalid_annotation_target

import 'package:bb_mobile/core_deprecated/storage/migrations/005_hive_to_sqlite/old/entities/old_address.dart';
import 'package:bb_mobile/core_deprecated/storage/migrations/005_hive_to_sqlite/old/entities/old_swap.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:timeago/timeago.dart' as timeago;

part 'old_transaction.freezed.dart';
part 'old_transaction.g.dart';

@freezed
abstract class OldTransaction with _$OldTransaction {
  const factory OldTransaction({
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
    @JsonKey(includeFromJson: false, includeToJson: false) Uint8List? pset,
    @Default(true) bool rbfEnabled,
    // @Default(false) bool oldTx,
    int? broadcastTime,
    // String? serializedTx,
    @Default([]) List<OldAddress> outAddrs,
    @Default([]) List<OldTxIn> inputs,
    @JsonKey(includeFromJson: false, includeToJson: false)
    bdk.TransactionDetails? bdkTx,
    // Wallet? wallet,
    @Default(false) bool isSwap,
    OldSwapTx? swapTx,
    @Default(false) bool isLiquid,
    @Default('') String unblindedUrl,
    @Default([]) List<String> rbfTxIds,
    String? walletId,
  }) = _Transaction;

  factory OldTransaction.fromSwapTx(OldSwapTx swapTx) {
    return OldTransaction(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      txid: swapTx.id,
      swapTx: swapTx,
      isSwap: true,
    );
  }
  const OldTransaction._();

  factory OldTransaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);

  bool swapIdisTxid() => swapTx != null && swapTx!.id == txid;

  Uint8List? get psbtAsBytes =>
      psbt == null ? null : Uint8List.fromList(psbt!.codeUnits);

  OldAddress? mapOutValueToAddress(int value) {
    if (outAddrs.isEmpty) return null;
    try {
      final OldAddress address = outAddrs.firstWhere(
        (element) => element.highestPreviousBalance == value,
      );
      return address;
    } catch (e) {
      return null;
    }
  }

  List<OldAddress> createOutAddrsFromTx() {
    final List<OldAddress> outAddrs = [];
    return outAddrs;
  }

  bool isReceived() =>
      sent == 0 || sent != null && received != null && received! > sent!;

  bool isReceivedCatchSelfPayment() =>
      sent == 0 || sent != null && received != null && received! > sent!;

  bool isToSelf() {
    if (!isReceived()) {
      final index = outAddrs.indexWhere(
        (element) => element.kind == OldAddressKind.deposit,
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

  /// Amount paid to the recipient of the transaction
  int getNetAmountToPayee() {
    try {
      return sent! - received!;
    } catch (e) {
      return 0;
    }
  }

  /// Amount spent by the wallet to effectuate the transaction
  int getNetAmountIncludingFees() {
    try {
      return getNetAmountToPayee() - fee!;
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

  DateTime? getBroadcastDateTime() =>
      broadcastTime == null
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
      input:
          (json['input'] as List?)
              ?.map((e) => OldInput.fromJson(e as Map<String, dynamic>))
              .toList(),
      output:
          (json['output'] as List?)
              ?.map((e) => OldOutput.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
  int? version;
  int? lockTime;
  List<OldInput>? input;
  List<OldOutput>? output;
}

@freezed
abstract class OldTxIn with _$OldTxIn {
  const factory OldTxIn({
    required String prevOut, // as txid:index
  }) = _TxIn;
  const OldTxIn._();

  factory OldTxIn.fromJson(Map<String, dynamic> json) => _$TxInFromJson(json);
}

class OldInput {
  OldInput({this.previousOutput, this.scriptSig, this.sequence, this.witness});

  factory OldInput.fromJson(Map<String, dynamic> json) {
    return OldInput(
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

class OldOutput {
  OldOutput({this.value, this.scriptPubkey});

  factory OldOutput.fromJson(Map<String, dynamic> json) {
    return OldOutput(
      value: json['value'] as int?,
      scriptPubkey: json['script_pubkey'] as String?,
    );
  }
  int? value;
  String? scriptPubkey;
}
