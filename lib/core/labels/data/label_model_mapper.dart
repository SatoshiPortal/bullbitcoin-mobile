import 'package:bb_mobile/core/labels/domain/label_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_datasource.dart';

extension LabelModelMapper on LabelModel {
  Label toEntity() {
    return Label(label: label, origin: origin, spendable: spendable);
  }
}
