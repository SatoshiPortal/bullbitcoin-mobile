import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'label.freezed.dart';

@freezed
sealed class Label with _$Label {
  const factory Label.tx({
    required String transactionId,
    required String label,
    String? origin,
  }) = TxLabel;

  const factory Label.addr({
    required String address,
    required String label,
    String? origin,
  }) = AddressLabel;

  const factory Label.pubkey({
    required String pubkey,
    required String label,
    String? origin,
  }) = PubkeyLabel;

  const factory Label.input({
    required String txId,
    required int vin,
    required String label,
    String? origin,
  }) = InputLabel;

  const factory Label.output({
    required String txId,
    required int vout,
    required String label,
    String? origin,
    bool? spendable,
  }) = OutputLabel;

  const factory Label.xpub({
    required String xpub,
    required String label,
    String? origin,
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
      TxLabel(transactionId: final txId, origin: _) => txId,
      AddressLabel(address: final addr, origin: _) => addr,
      PubkeyLabel(pubkey: final pubkey, origin: _) => pubkey,
      InputLabel(txId: final txId, vin: final vin, origin: _) => '$txId:$vin',
      OutputLabel(txId: final txId, vout: final vout, origin: _) =>
        '$txId:$vout',
      XpubLabel(xpub: final xpub, origin: _) => xpub,
    };
  }
}
