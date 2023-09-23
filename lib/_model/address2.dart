// ignore_for_file: invalid_annotation_target

import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'address2.freezed.dart';
part 'address2.g.dart';

enum AddressKind {
  deposit,
  change,
  external,
}

enum AddressState {
  unset,
  unused,
  active,
  frozen,
  used,
}

@freezed
class Address2 with _$Address2 {
  factory Address2({
    required String address,
    required int index,
    required AddressKind kind,
    required AddressState state,
    String? label,
    String? spentTxId,
    bool? isReceive,
    @Default(false) bool saving,
    @Default('') String errSaving,
    @Default(0) int highestPreviousBalance,
    @JsonKey(
      includeFromJson: false,
      includeToJson: false,
    )
    List<bdk.LocalUtxo>? utxos,
  }) = _Address2;
  const Address2._();

  factory Address2.fromJson(Map<String, dynamic> json) => _$Address2FromJson(json);

  int calculateBalance() {
    return utxos?.fold(
          0,
          (amt, tx) => tx.isSpent ? amt : (amt ?? 0) + tx.txout.value,
        ) ??
        0;
  }

  List<bdk.OutPoint> getUnspentUtxosOutpoints() {
    return utxos?.where((tx) => !tx.isSpent).map((tx) => tx.outpoint).toList() ?? [];
  }

  bool hasSpentAndNoBalance() {
    return (utxos?.where((tx) => tx.isSpent).isNotEmpty ?? false) && calculateBalance() == 0;
  }

  String miniString() {
    return address.substring(0, 6) + '...' + address.substring(address.length - 6);
  }

  String largeString() {
    return address.substring(0, 10) + '...' + address.substring(address.length - 10);
  }
}
