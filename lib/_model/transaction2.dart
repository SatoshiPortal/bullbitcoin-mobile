// ignore_for_file: invalid_annotation_target

import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction2.freezed.dart';
part 'transaction2.g.dart';

@freezed
class Transaction2 with _$Transaction2 {
  const factory Transaction2({
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
    bool? rbfEnabled,
    @Default(false)
        bool oldTx,
    int? broadcastTime,
    // String? serializedTx,
    List<String>? vins, // address:vin[]
    List<String>? vouts, // address:vout[]
    @JsonKey(
      includeFromJson: false,
      includeToJson: false,
    )
        bdk.TransactionDetails? bdkTx,
  }) = _Transaction2;
  const Transaction2._();

  factory Transaction2.fromJson(Map<String, dynamic> json) => _$Transaction2FromJson(json);

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

  bool canRBF() =>
      //  (rbfEnabled ?? false) &&
      timestamp == null || timestamp == 0;
}

DateTime getDateTimeFromInt(int time) => DateTime.fromMillisecondsSinceEpoch(time * 1000);
