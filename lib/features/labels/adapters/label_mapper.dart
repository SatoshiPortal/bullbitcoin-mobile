import 'package:bb_mobile/core/storage/storage.dart';
import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';

class LabelMapper {
  static LabelsCompanion fromEntity(LabelEntity label) {
    final type = switch (label.type) {
      LabelType.extendedPublicKey => LabelTypeColumn.xpub,
      LabelType.transaction => LabelTypeColumn.tx,
      LabelType.address => LabelTypeColumn.address,
      LabelType.input => LabelTypeColumn.input,
      LabelType.output => LabelTypeColumn.output,
      LabelType.publicKey => LabelTypeColumn.pubkey,
    };

    return LabelsCompanion(
      label: Value(label.label),
      reference: Value(label.reference),
      type: Value(type),
      origin: Value(label.origin),
      id: label.id != null ? Value(label.id!) : const Value.absent(),
    );
  }

  static LabelEntity toEntity(LabelRow row) {
    final type = switch (row.type) {
      LabelTypeColumn.xpub => LabelType.extendedPublicKey,
      LabelTypeColumn.tx => LabelType.transaction,
      LabelTypeColumn.address => LabelType.address,
      LabelTypeColumn.input => LabelType.input,
      LabelTypeColumn.output => LabelType.output,
      LabelTypeColumn.pubkey => LabelType.publicKey,
    };

    return LabelEntity(
      type: type,
      label: row.label,
      reference: row.reference,
      origin: row.origin,
    );
  }
}
