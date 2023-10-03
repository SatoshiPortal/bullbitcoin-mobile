// ignore_for_file: invalid_annotation_target

import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'address.freezed.dart';
part 'address.g.dart';

enum AddressKind {
  deposit,
  change,
  external,
}

enum AddressStatus {
  unset,
  unused,
  active,
  used,
  copied,
}

@freezed
class Address with _$Address {
  factory Address({
    required String address,
    int? index,
    required AddressKind kind,
    required AddressStatus state,
    String? label,
    String? spentTxId,
    @Default(true) bool spendable,
    @Default(false) bool saving,
    @Default('') String errSaving,
    @Default(0) int highestPreviousBalance,
    @JsonKey(
      includeFromJson: false,
      includeToJson: false,
    )
    List<bdk.LocalUtxo>? utxos,
  }) = _Address;
  const Address._();

  factory Address.fromJson(Map<String, dynamic> json) => _$AddressFromJson(json);

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

  bool hasInternal() {
    return utxos?.where((tx) => tx.keychain == bdk.KeychainKind.Internal).isNotEmpty ?? false;
  }

  bool hasExternal() {
    return utxos?.where((tx) => tx.keychain == bdk.KeychainKind.External).isNotEmpty ?? false;
  }

  String miniString() {
    return address.substring(0, 6) + '[...]' + address.substring(address.length - 6);
  }

  String largeString() {
    return address.substring(0, 10) + '[...]' + address.substring(address.length - 10);
  }
}
