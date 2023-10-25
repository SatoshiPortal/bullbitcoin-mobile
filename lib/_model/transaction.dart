// ignore_for_file: invalid_annotation_target

import 'package:bb_mobile/_model/address.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:timeago/timeago.dart' as timeago;

part 'transaction.freezed.dart';
part 'transaction.g.dart';

@freezed
class Transaction with _$Transaction {
  const factory Transaction({
    required String txid,
    int? received,
    int? sent,
    int? fee,
    int? height,
    int? timestamp,
    String? label,
    String? fromAddress,
    String? toAddress,
    String? psbt,
    @Default(false) bool rbfEnabled,
    @Default(false) bool oldTx,
    int? broadcastTime,
    // String? serializedTx,
    List<String>? inAddresses,
    List<String>? outAddresses,
    @Default([]) List<Address> outAddrs,
    @JsonKey(
      includeFromJson: false,
      includeToJson: false,
    )
    bdk.TransactionDetails? bdkTx,
  }) = _Transaction;
  const Transaction._();

  factory Transaction.fromJson(Map<String, dynamic> json) => _$TransactionFromJson(json);

  String mapOutValueToAddress(String value) {
    if (outAddresses == null) return '';
    final String address = outAddresses!.firstWhere(
      (element) => element.split(':')[1] == value,
      orElse: () => '',
    );
    return address.split(':')[0];
  }

  List<Address> createOutAddrsFromTx() {
    final List<Address> outAddrs = [];
    return outAddrs;
  }

  bool isReceived() => sent == 0 || sent != null && received != null && received! > sent!;

  bool isReceivedCatchSelfPayment() =>
      sent == 0 || sent != null && received != null && received! > sent!;

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
    return DateTime.fromMillisecondsSinceEpoch(timestamp! * 1000);
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
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp! * 1000);
    if (dt.isAfter(DateTime.now().subtract(const Duration(days: 2)))) return timeago.format(dt);
    final day = dt.day.toString().length == 1 ? '0${dt.day}' : dt.day.toString();
    return months[dt.month - 1] + ' ' + day + ', ' + dt.year.toString();
  }

  DateTime? getBroadcastDateTime() =>
      broadcastTime == null ? null : DateTime.fromMillisecondsSinceEpoch(broadcastTime!);

  bool canRBF() => rbfEnabled == true && timestamp == null || timestamp == 0;

  // List<Address> outputAddressesFromSerialized() {
  //   final serialized = bdkTx!.serializedTx;

  // }
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
