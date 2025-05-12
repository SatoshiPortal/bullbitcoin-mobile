// ignore_for_file: invalid_annotation_target

import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'old_address.freezed.dart';
part 'old_address.g.dart';

enum OldAddressKind { deposit, change, external }

enum OldAddressStatus { unused, active, used, copied }

@freezed
abstract class OldAddress with _$OldAddress {
  factory OldAddress({
    required String address,
    // for btc, this holds regular address; for liquid, this hold confidential address
    // String? confidential, // For liquid // not used now // remove this
    String? standard, // For liquid
    int? index,
    required OldAddressKind kind,
    required OldAddressStatus state,
    String? label,
    String? spentTxId,
    @Default(true) bool spendable,
    @Default(0) int highestPreviousBalance,
    @Default(0) int balance,
    @Default(false) bool isLiquid,
  }) = _Address;
  const OldAddress._();

  factory OldAddress.fromJson(Map<String, dynamic> json) =>
      _$OldAddressFromJson(json);

  // TODO: OldUTXO
  // Updated with OldUTXO change
  List<bdk.OutPoint> getUnspentUtxosOutpoints(List<OldUTXO> utxos) {
    return utxos
        .where((ut) => ut.address.address == address)
        .map((e) => bdk.OutPoint(txid: e.txid, vout: e.txIndex))
        .toList();
    // return utxos?.where((tx) => !tx.isSpent).map((tx) => tx.outpoint).toList() ?? [];
  }

  String miniString() {
    return '${address.substring(0, 6)}[...]${address.substring(address.length - 6)}';
  }

  String largeString() {
    return '${address.substring(0, 10)}[...]${address.substring(address.length - 10)}';
  }

  String toShortString() {
    return '${address.substring(0, 5)}...${address.substring(address.length - 5)}';
  }

  String getKindString() {
    switch (kind) {
      case OldAddressKind.deposit:
        return 'Receive';
      case OldAddressKind.change:
        return 'Change';
      case OldAddressKind.external:
        return 'External';
    }
  }
}

@freezed
abstract class OldUTXO with _$OldUTXO {
  factory OldUTXO({
    required String txid,
    required int txIndex,
    required bool isSpent,
    required int value,
    required String label,
    required OldAddress address,
    required bool spendable,
  }) = _UTXO;
  const OldUTXO._();

  factory OldUTXO.fromJson(Map<String, dynamic> json) => _$UTXOFromJson(json);

  @override
  String toString() {
    return '$txid:$txIndex';
  }

  bdk.OutPoint getUtxosOutpoints() {
    return bdk.OutPoint(txid: txid, vout: txIndex);
  }
}

extension OldY on List<OldUTXO> {
  bool containsUtxo(OldUTXO utxo) =>
      where((utx) => utx.toString() == utxo.toString()).isNotEmpty;

  List<OldUTXO> removeUtxo(OldUTXO utxo) =>
      where((utx) => utx.toString() != utxo.toString()).toList();
}
