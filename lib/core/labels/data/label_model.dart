import 'package:bb_mobile/core/labels/domain/label_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'label_model.freezed.dart';

@freezed
abstract class LabelModel with _$LabelModel {
  const factory LabelModel({
    required String label,
    required String ref,
    required String type,
    String? origin,
    bool? spendable,
  }) = _LabelModel;
}

extension LabelModelMapper on LabelModel {
  static LabelModel fromSqlite(LabelRow row) => LabelModel(
    label: row.label,
    ref: row.ref,
    type: row.type,
    origin: row.origin,
    spendable: row.spendable,
  );

  LabelRow toSqlite() => LabelRow(
    label: label,
    ref: ref,
    type: type,
    origin: origin,
    spendable: spendable,
  );

  Label toEntity() {
    return Label(label: label, origin: origin, spendable: spendable);
  }
}
