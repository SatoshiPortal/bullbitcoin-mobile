// ignore_for_file: invalid_annotation_target

import 'package:bb_mobile/_model/address.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:freezed_annotation/freezed_annotation.dart';

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

  bool isReceived() => sent == 0;

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

  DateTime getDateTime() => DateTime.fromMillisecondsSinceEpoch(timestamp! * 1000);

  DateTime? getBroadcastDateTime() =>
      broadcastTime == null ? null : DateTime.fromMillisecondsSinceEpoch(broadcastTime!);

  bool canRBF() => rbfEnabled == true && timestamp == null || timestamp == 0;
}

DateTime getDateTimeFromInt(int time) => DateTime.fromMillisecondsSinceEpoch(time * 1000);
