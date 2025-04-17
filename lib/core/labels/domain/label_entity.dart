// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'label_entity.freezed.dart';

// BIP329 Standard Label
@freezed
class Label with _$Label {
  const factory Label({
    required String label,
    String? origin,
    bool? spendable,
  }) = _Label;
  const Label._();
}
