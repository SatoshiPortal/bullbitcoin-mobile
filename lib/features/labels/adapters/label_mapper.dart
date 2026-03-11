import 'package:bb_mobile/core/storage/storage.dart';
import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:bb_mobile/features/labels/application/application_label.dart';
import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/new_label.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';
import 'package:bb_mobile/features/labels/label.dart';

class LabelMapper {
  static LabelsCompanion newLabelEntityToCompanion(NewLabel newLabel) {
    final type = _labelTypeToColumnType(newLabel.type);

    return LabelsCompanion(
      id: newLabel.id != null ? Value(newLabel.id!) : const Value.absent(),
      label: Value(newLabel.label),
      reference: Value(newLabel.reference),
      type: Value(type),
      origin: Value(newLabel.origin),
    );
  }

  static LabelsCompanion labelEntityToCompanion(LabelEntity label) {
    final type = _labelTypeToColumnType(label.type);

    return LabelsCompanion(
      id: Value(label.id),
      label: Value(label.label),
      reference: Value(label.reference),
      type: Value(type),
      origin: Value(label.origin),
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

  static ApplicationLabel labelEntityToApplicationLabel(LabelEntity label) {
    return ApplicationLabel(
      id: label.id,
      type: label.type,
      label: label.label,
      reference: label.reference,
      origin: label.origin,
    );
  }

  static LabelEntity applicationLabelToLabelEntity(
    ApplicationLabel applicationLabel,
  ) {
    return LabelEntity(
      id: applicationLabel.id,
      type: applicationLabel.type,
      label: applicationLabel.label,
      reference: applicationLabel.reference,
      origin: applicationLabel.origin,
    );
  }

  static Label applicationLabelToLabel(ApplicationLabel applicationLabel) {
    return Label(
      id: applicationLabel.id,
      type: applicationLabel.type,
      label: applicationLabel.label,
      reference: applicationLabel.reference,
      origin: applicationLabel.origin,
    );
  }

  static ApplicationLabel labelToApplicationLabel(Label label) {
    return ApplicationLabel(
      id: label.id,
      type: label.type,
      label: label.label,
      reference: label.reference,
      origin: label.origin,
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
