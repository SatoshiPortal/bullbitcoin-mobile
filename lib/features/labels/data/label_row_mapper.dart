import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:bb_mobile/features/labels/domain/label.dart';

extension LabelRowMapper on LabelRow {
  static LabelRow fromEntity(Label label) {
    return LabelRow(
      label: label.label,
      ref: label.ref,
      type: label.type,
      origin: switch (label) {
        TxLabel(:final origin) => origin,
        AddressLabel(:final origin) => origin,
        PubkeyLabel(:final origin) => origin,
        InputLabel(:final origin) => origin,
        OutputLabel(:final origin) => origin,
        XpubLabel(:final origin) => origin,
      },
      spendable: label is OutputLabel ? label.spendable : null,
    );
  }

  Label toEntity() {
    return switch (type) {
      LabelType.tx => Label.tx(
        transactionId: ref,
        label: label,
        origin: origin,
      ),
      LabelType.address => Label.addr(
        address: ref,
        label: label,
        origin: origin,
      ),
      LabelType.pubkey => Label.pubkey(
        pubkey: ref,
        label: label,
        origin: origin,
      ),
      LabelType.input => Label.input(
        txId: ref.split(':')[0],
        vin: int.parse(ref.split(':')[1]),
        label: label,
        origin: origin,
      ),
      LabelType.output => Label.output(
        txId: ref.split(':')[0],
        vout: int.parse(ref.split(':')[1]),
        label: label,
        origin: origin,
        spendable: spendable,
      ),
      LabelType.xpub => Label.xpub(xpub: ref, label: label, origin: origin),
    };
  }
}
