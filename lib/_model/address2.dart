// ignore_for_file: invalid_annotation_target

import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'address2.freezed.dart';
part 'address2.g.dart';

enum AddressType {
  receiveActive,
  receiveUnused,
  receiveUsed,
  changeActive,
  changeUsed,
  notMine,
}

/// spend: myChange or Deposit txvout becomes a new txvin and new txvout is notMine and myChange
/// receive: txvin is notMine and vout is myDeposit
/// change is only created via spend, receive is only to deposit addresses
@freezed
class Address2 with _$Address2 {
  factory Address2({
    required String address,
    required int index,
    required AddressType type,
    List<String>? txVIns, // txid:vin[]
    // notMine: receive tx, myChange/myDeposit: spend tx
    List<String>? txVOuts, // txid:vout[]
    // myDeposit: receive tx, notMine/myChange: spend tx
    @Default(0)
        int? balance,
    @Default('')
        String? label,
    @JsonKey(
      includeFromJson: false,
      includeToJson: false,
    )
        List<bdk.LocalUtxo>? utxos, // exists if this address has active utxos
  }) = _Address2;
  const Address2._();

  factory Address2.fromJson(Map<String, dynamic> json) => _$Address2FromJson(json);

  String miniString() {
    return address.substring(0, 6) + '...' + address.substring(address.length - 6);
  }

  bool isSpendable() {
    return type != AddressType.notMine ||
        type != AddressType.receiveUsed ||
        type != AddressType.changeUsed;
  }

  bool isReUsed() {
    return txVOuts!.length > 1;
  }

  String largeString() {
    return address.substring(0, 10) + '...' + address.substring(address.length - 10);
  }
}
