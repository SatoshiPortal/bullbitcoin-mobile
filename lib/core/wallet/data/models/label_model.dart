import 'package:bb_mobile/core/wallet/domain/entity/labels.dart';

class LabelModel {
  final String type;
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

  factory LabelModel.fromEntity(Label entity) {
    return LabelModel(
      type: entity.type.value,
      ref: entity.ref,
      label: entity.label,
      origin: entity.origin,
      spendable: entity.spendable,
    );
  }

  Label toEntity() {
    return Label(
      type: _typeFromString(type),
      ref: ref,
      label: label,
      origin: origin,
      spendable: spendable,
    );
  }

  LabelType _typeFromString(String typeStr) {
    switch (typeStr) {
      case 'tx':
        return LabelType.tx;
      case 'address':
        return LabelType.address;
      case 'pubkey':
        return LabelType.pubkey;
      case 'input':
        return LabelType.input;
      case 'output':
        return LabelType.output;
      case 'xpub':
        return LabelType.xpub;
      default:
        throw ArgumentError('Invalid label type: $typeStr');
    }
  }

  factory LabelModel.fromJson(Map<String, dynamic> json) {
    return LabelModel(
      type: json['type'] as String,
      ref: json['ref'] as String,
      label: json['label'] as String,
      origin: json['origin'] as String?,
      spendable: json['spendable'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'ref': ref,
      'label': label,
      if (origin != null) 'origin': origin,
      if (spendable != null) 'spendable': spendable,
    };
  }
}
