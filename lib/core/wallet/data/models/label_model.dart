import 'package:bb_mobile/core/wallet/domain/entity/labels.dart';

class Bip329LabelModel {
  final String type;
  final String ref;
  final String label; // Single label instead of a list
  final String? origin;
  final bool? spendable;

  Bip329LabelModel({
    required this.type,
    required this.ref,
    required this.label,
    this.origin,
    this.spendable,
  });

  // Convert from entity to model
  factory Bip329LabelModel.fromEntity(Bip329Label entity) {
    return Bip329LabelModel(
      type: entity.type.value,
      ref: entity.ref,
      label: entity.label,
      origin: entity.origin,
      spendable: entity.spendable,
    );
  }

  // Convert from model to entity
  Bip329Label toEntity() {
    return Bip329Label(
      type: _typeFromString(type),
      ref: ref,
      label: label,
      origin: origin,
      spendable: spendable,
    );
  }

  // Helper to convert string to BIP329Type enum
  BIP329Type _typeFromString(String typeStr) {
    switch (typeStr) {
      case 'tx':
        return BIP329Type.tx;
      case 'address':
        return BIP329Type.address;
      case 'pubkey':
        return BIP329Type.pubkey;
      case 'input':
        return BIP329Type.input;
      case 'output':
        return BIP329Type.output;
      case 'xpub':
        return BIP329Type.xpub;
      default:
        throw ArgumentError('Invalid label type: $typeStr');
    }
  }

  // Convert from json to model
  factory Bip329LabelModel.fromJson(Map<String, dynamic> json) {
    return Bip329LabelModel(
      type: json['type'] as String,
      ref: json['ref'] as String,
      label: json['label'] as String,
      origin: json['origin'] as String?,
      spendable: json['spendable'] as bool?,
    );
  }

  // Convert from model to json
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
