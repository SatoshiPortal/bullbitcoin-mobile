import 'package:bb_mobile/core/labels/data/label_storage_datasource.dart';

class LabelModel {
  final Entity type;
  final String ref;
  final String label;
  final String? origin;
  final bool? spendable;

  LabelModel({
    required this.type,
    required this.ref,
    required this.label,
    this.origin,
    this.spendable,
  });

  factory LabelModel.fromJson(Map<String, dynamic> json) {
    return LabelModel(
      type: Entity.from(json['type'] as String),
      ref: json['ref'] as String,
      label: json['label'] as String,
      origin: json['origin'] as String?,
      spendable: json['spendable'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'ref': ref,
      'label': label,
      if (origin != null) 'origin': origin,
      if (spendable != null) 'spendable': spendable,
    };
  }
}
