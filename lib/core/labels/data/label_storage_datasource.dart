import 'dart:convert';

import 'package:bb_mobile/core/address/domain/entities/address.dart';
import 'package:bb_mobile/core/labels/data/label_model.dart';
import 'package:bb_mobile/core/transaction/domain/entities/transaction.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Entity {
  label,
  tx,
  address,
  pubkey,
  input,
  output,
  xpub;

  static Entity from(String string) {
    switch (string) {
      case 'label':
        return Entity.label;
      case 'tx':
        return Entity.tx;
      case 'address':
        return Entity.address;
      case 'pubkey':
        return Entity.pubkey;
      case 'input':
        return Entity.input;
      case 'output':
        return Entity.output;
      case 'xpub':
        return Entity.xpub;
      default:
        throw ArgumentError('Invalid entity type: $string');
    }
  }

  static Entity fromType(dynamic type) {
    if (type == Transaction) {
      return Entity.tx;
    } else if (type == Address) {
      return Entity.address;
    } else {
      throw ArgumentError('Invalid entity type: $type');
    }
  }

  /// Since a label may contains any kind of char
  /// use the ASCII Unit Separator
  static String get separator => '␟';
}

class LabelStorageDatasource {
  final SharedPreferencesAsync _labelStorage;

  LabelStorageDatasource() : _labelStorage = SharedPreferencesAsync();

  Future<void> store(LabelModel label) async {
    final labelKey = _encode(Entity.label, label.label);
    final entityKey = _encode(label.type, label.ref);
    final jsonLabelModel = json.encode(label.toJson());

    _storeOrUpdate(entityKey, jsonLabelModel);
    _storeOrUpdate(labelKey, jsonLabelModel);
  }

  Future<List<LabelModel>> _fetch(Entity prefix, String entity) async {
    final anEntity = _encode(prefix, entity);
    final values = await _labelStorage.getStringList(anEntity) ?? [];

    return values
        .map((v) => LabelModel.fromJson(json.decode(v) as Map<String, dynamic>))
        .toList();
  }

  Future<List<LabelModel>> fetchByRef(Entity prefix, String ref) {
    return _fetch(prefix, ref);
  }

  Future<List<LabelModel>> fetchByLabel(String label) {
    return _fetch(Entity.label, label);
  }

  /// Reads all labels stored in the main storage
  /// Returns a list of all LabelModel objects across all keys
  Future<List<LabelModel>> fetchAll() async {
    final all = await _labelStorage.getAll();
    final labelKeys = all.keys.where((k) => k.startsWith(Entity.label.name));

    final result = <LabelModel>[];
    for (final labelKey in labelKeys) {
      final (prefix, label) = _decode(labelKey);
      final labelModels = await _fetch(prefix, label);
      result.addAll(labelModels);
    }
    return result;
  }

  Future<void> trash(String label) async {
    final aLabel = _encode(Entity.label, label);

    // Fetch all entities related to this label
    final entities = await _labelStorage.getStringList(aLabel) ?? [];

    // Delete each entity associated with this label
    for (final e in entities) {
      _labelStorage.remove(e);
    }
  }

  Future<void> trashAll() async => await _labelStorage.clear();

  Future<void> _storeOrUpdate(String key, String value) async {
    // Fetch all values related to this key
    final existingValues = await _labelStorage.getStringList(key) ?? [];

    if (!existingValues.contains(value)) {
      final updatedValues = [...existingValues, value];
      await _labelStorage.setStringList(key, updatedValues);
    }
  }

  String _encode(Entity prefix, String entity) {
    return '${prefix.name}${Entity.separator}$entity';
  }

  (Entity, String) _decode(String entityWithPrefix) {
    final parts = entityWithPrefix.split(Entity.separator);
    final prefix = Entity.from(parts.first);
    final entity = parts.last;
    return (prefix, entity);
  }
}
