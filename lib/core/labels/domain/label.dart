import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'label.freezed.dart';

@freezed
sealed class Label with _$Label {
  const factory Label.tx({
    required String transactionId,
    required String label,
    String? walletId,
  }) = TxLabel;

  const factory Label.addr({
    required String address,
    required String label,
    String? walletId,
  }) = AddressLabel;

  const factory Label.pubkey({
    required String pubkey,
    required String label,
    String? walletId,
  }) = PubkeyLabel;

  const factory Label.input({
    required String txId,
    required int vin,
    required String label,
    String? walletId,
  }) = InputLabel;

  const factory Label.output({
    required String txId,
    required int vout,
    required String label,
    String? walletId,
    bool? spendable,
  }) = OutputLabel;

  const factory Label.xpub({
    required String xpub,
    required String label,
    String? walletId,
  }) = XpubLabel;
  const Label._();

  LabelType get type {
    return switch (this) {
      TxLabel() => LabelType.tx,
      AddressLabel() => LabelType.address,
      PubkeyLabel() => LabelType.pubkey,
      InputLabel() => LabelType.input,
      OutputLabel() => LabelType.output,
      XpubLabel() => LabelType.xpub,
    };
  }

  String get ref {
    return switch (this) {
      TxLabel(transactionId: final txId, walletId: _) => txId,
      AddressLabel(address: final addr, walletId: _) => addr,
      PubkeyLabel(pubkey: final pubkey, walletId: _) => pubkey,
      InputLabel(txId: final txId, vin: final vin, walletId: _) => '$txId:$vin',
      OutputLabel(txId: final txId, vout: final vout, walletId: _) =>
        '$txId:$vout',
      XpubLabel(xpub: final xpub, walletId: _) => xpub,
    };
  }
}
