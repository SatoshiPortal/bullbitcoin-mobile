import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/labels_table.dart' as db;
import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/primitive/label_type.dart';

extension LabelRowMapper on LabelRow {
  static LabelRow fromEntity(LabelEntity label) {
    final type = switch (label.type) {
      LabelType.extendedPublicKey => db.LabelType.xpub,
      LabelType.transaction => db.LabelType.tx,
      LabelType.address => db.LabelType.address,
      LabelType.input => db.LabelType.input,
      LabelType.output => db.LabelType.output,
      LabelType.publicKey => db.LabelType.pubkey,
    };

    return LabelRow(
      label: label.label,
      ref: label.reference,
      type: type,
      origin: label.origin,
      spendable: label.spendable ?? true,
    );
  }

  LabelEntity toEntity() {
    final type = switch (this.type) {
      db.LabelType.xpub => LabelType.extendedPublicKey,
      db.LabelType.tx => LabelType.transaction,
      db.LabelType.address => LabelType.address,
      db.LabelType.input => LabelType.input,
      db.LabelType.output => LabelType.output,
      db.LabelType.pubkey => LabelType.publicKey,
    };

    return LabelEntity(
      type: type,
      label: label,
      reference: ref,
      origin: origin,
      spendable: spendable,
    );
  }
}
