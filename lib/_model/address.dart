// ignore_for_file: invalid_annotation_target

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
    // @Default(false) bool saving,
    // @Default('') String errSaving,
    @Default(0) int highestPreviousBalance,
    @Default(0) int balance,
    // @JsonKey(
    //   includeFromJson: false,
    //   includeToJson: false,
    // )
    // List<bdk.LocalUtxo>? utxos,
    // List<UTXO>? localUtxos,
  }) = _Address;
  const Address._();

  factory Address.fromJson(Map<String, dynamic> json) => _$AddressFromJson(json);

  int calculateBalance() {
    return balance;
    // TODO: UTXO
    /*
    return utxos?.fold(
          0,
          (amt, tx) => tx.isSpent ? amt : (amt ?? 0) + tx.txout.value,
        ) ??
        0;
    */
  }

  int calculateBalanceLocal() {
    print('calculateBalanceLocal: $balance');
    return balance;
    /*
    // TODO: UTXO
    return localUtxos?.fold(
          0,
          (amt, tx) => tx.isSpent ? amt : (amt ?? 0) + tx.value,
        ) ??
        0;
    */
  }

  List<bdk.OutPoint> getUnspentUtxosOutpoints() {
    return [];
    // TODO: UTXO
    // return utxos?.where((tx) => !tx.isSpent).map((tx) => tx.outpoint).toList() ?? [];
  }

  bool hasSpentAndNoBalance() {
    return false;
    // TODO: UTXO
    // return (utxos?.where((tx) => tx.isSpent).isNotEmpty ?? false) && calculateBalance() == 0;
  }

  bool hasInternal() {
    return false;
    // TODO: UTXO
    // return utxos?.where((tx) => tx.keychain == bdk.KeychainKind.Internal).isNotEmpty ?? false;
  }

  bool hasExternal() {
    return false;
    // TODO: UTXO
    // return utxos?.where((tx) => tx.keychain == bdk.KeychainKind.External).isNotEmpty ?? false;
  }

  String miniString() {
    return address.substring(0, 6) + '[...]' + address.substring(address.length - 6);
  }

  String largeString() {
    return address.substring(0, 10) + '[...]' + address.substring(address.length - 10);
  }

  String getKindString() {
    switch (kind) {
      case AddressKind.deposit:
        return 'Receive';
      case AddressKind.change:
        return 'Change';
      case AddressKind.external:
        return 'External';
    }
  }
}

@freezed
class UTXO with _$UTXO {
  factory UTXO({
    required String txid,
    required int txIndex,
    required bool isSpent,
    required int value,
    required String label,
    required Address address,
    required bool spendable,
  }) = _UTXO;
  const UTXO._();

  factory UTXO.fromJson(Map<String, dynamic> json) => _$UTXOFromJson(json);

/*
  static List<UTXO> fromUTXOList(List<bdk.LocalUtxo> utxos) {
    return utxos
        .map(
          (utxo) => UTXO(
            txid: utxo.outpoint.txid,
            txIndex: utxo.outpoint.vout,
            isSpent: utxo.isSpent,
            value: utxo.txout.value,
            label: '',
          ),
        )
        .toList();
  }
  */
}

// TODO: UTXO (Remove)
extension X on List<Address> {
  bool containsAddress(Address address) =>
      where((addr) => addr.address == address.address).isNotEmpty;

  List<Address> removeAddress(Address address) =>
      where((addr) => addr.address != address.address).toList();
}

extension Y on List<UTXO> {
  bool containsUtxo(UTXO utxo) => where((utx) => utx.address == utxo.address).isNotEmpty;

  List<UTXO> removeUtxo(UTXO utxo) => where((utx) => utx.address != utxo.address).toList();
}

// @freezed
// class TxOut with _$TxOut {
//   factory TxOut({
//     required int value,
//     required bdk.Script scriptPubkey,
//   }) = _TxOut;
//   const TxOut._();

//   factory TxOut.fromJson(Map<String, dynamic> json) => _$TxOutFromJson(json);
// }

// @freezed
// class OutPoint with _$OutPoint {
//   factory OutPoint({
//     required String txid,
//     required int vout,
//   }) = _OutPoint;
//   const OutPoint._();

//   factory OutPoint.fromJson(Map<String, dynamic> json) => _$OutPointFromJson(json);
// }

// class LocalUtxo {
//   /// Reference to a transaction output
//   final OutPoint outpoint;

//   ///Transaction output
//   final TxOut txout;

//   ///Whether this UTXO is spent or not
//   final bool isSpent;
//   final KeychainKind keychain;

//   const LocalUtxo({
//     required this.outpoint,
//     required this.txout,
//     required this.isSpent,
//     required this.keychain,
//   });
// }
