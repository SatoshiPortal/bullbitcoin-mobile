import 'package:drift/drift.dart';
import 'package:labels/labels_table.dart';
import 'package:labels/labels_table.drift.dart';
import 'package:labels/src/domain/label_entity.dart';
import 'package:labels/src/domain/new_label.dart';
import 'package:labels/src/domain/primitive/label_type.dart';

class LabelRowMapper {
  static LabelsTableCompanion newLabelEntityToCompanion(NewLabel newLabel) {
    final type = _labelTypeToColumnType(newLabel.type);

    final id = newLabel.id;
    return LabelsTableCompanion(
      id: id == null ? const Value.absent() : Value(id),
      label: Value(newLabel.label),
      reference: Value(newLabel.reference),
      type: Value(type),
      origin: Value(newLabel.origin),
    );
  }

  static LabelEntity toLabelEntity(LabelRow row) {
    final type = switch (row.type) {
      LabelTypeColumn.xpub => LabelType.extendedPublicKey,
      LabelTypeColumn.tx => LabelType.transaction,
      LabelTypeColumn.address => LabelType.address,
      LabelTypeColumn.input => LabelType.input,
      LabelTypeColumn.output => LabelType.output,
      LabelTypeColumn.pubkey => LabelType.publicKey,
    };

    return LabelEntity(
      id: row.id,
      type: type,
      label: row.label,
      reference: row.reference,
      origin: row.origin,
    );
  }

  static LabelTypeColumn _labelTypeToColumnType(LabelType type) {
    return switch (type) {
      LabelType.extendedPublicKey => LabelTypeColumn.xpub,
      LabelType.transaction => LabelTypeColumn.tx,
      LabelType.address => LabelTypeColumn.address,
      LabelType.input => LabelTypeColumn.input,
      LabelType.output => LabelTypeColumn.output,
      LabelType.publicKey => LabelTypeColumn.pubkey,
    };
  }
}
