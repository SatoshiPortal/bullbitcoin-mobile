import 'package:bb_mobile/core/labels/domain/label.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'label_model.freezed.dart';

@freezed
abstract class LabelModel with _$LabelModel {
  const factory LabelModel({
    required String label,
    required String ref,
    required LabelType type,
    String? origin,
    bool? spendable,
  }) = _LabelModel;
  const LabelModel._();

  factory LabelModel.fromSqlite(LabelRow row) => LabelModel(
    label: row.label,
    ref: row.ref,
    type: row.type,
    origin: row.origin,
    spendable: row.spendable,
  );

  factory LabelModel.fromEntity(Label label) {
    return LabelModel(
      label: label.label,
      ref: label.ref,
      type: label.type,
      origin: label.walletId,
      spendable: label is OutputLabel ? label.spendable : null,
    );
  }

  LabelRow toSqlite() => LabelRow(
    label: label,
    ref: ref,
    type: type,
    origin: origin,
    spendable: spendable,
  );

  Label toEntity() {
    switch (type) {
      case LabelType.tx:
        return Label.tx(
          transactionId: ref,
          label: label,
          walletId: origin ?? '',
        );
      case LabelType.address:
        return Label.addr(address: ref, label: label, walletId: origin ?? '');
      case LabelType.pubkey:
        return Label.pubkey(pubkey: ref, label: label, walletId: origin ?? '');
      case LabelType.input:
        final parts = ref.split(':');
        if (parts.length != 2) {
          throw ArgumentError('Invalid input ref format: $ref');
        }
        return Label.input(
          txId: parts[0],
          vin: int.parse(parts[1]),
          label: label,
          walletId: origin ?? '',
        );
      case LabelType.output:
        final parts = ref.split(':');
        if (parts.length != 2) {
          throw ArgumentError('Invalid output ref format: $ref');
        }
        return Label.output(
          txId: parts[0],
          vout: int.parse(parts[1]),
          label: label,
          walletId: origin ?? '',
          spendable: spendable,
        );
      case LabelType.xpub:
        return Label.xpub(xpub: ref, label: label, walletId: origin ?? '');
    }
  }
}
