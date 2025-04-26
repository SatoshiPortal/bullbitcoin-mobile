import 'dart:convert';

import 'package:bb_mobile/core/labels/data/label_model.dart';
import 'package:bb_mobile/core/labels/data/labelable.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_input.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_output.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:flutter/foundation.dart';
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
        throw ArgumentError('Invalid type: $string');
    }
  }

  static Entity fromLabelable(Labelable entity) {
    if (entity is WalletTransaction) {
      return Entity.tx;
    } else if (entity is WalletAddress) {
      return Entity.address;
    } else if (entity is TransactionInput) {
      return Entity.input;
    } else if (entity is TransactionOutput) {
      return Entity.output;
    }

    throw ArgumentError('Invalid type: $entity');
  }

  /// Since a label may contains any kind of char
  /// use the ASCII Unit Separator
  static String get separator => '␟';
}

class LabelStorageDatasource {
  final SharedPreferencesAsync _labelStorage;

  LabelStorageDatasource() : _labelStorage = SharedPreferencesAsync();

  Future<void> store(LabelModel label) async {
    try {
      final labelKey = _encode(Entity.label, label.label);
      final entityKey = _encode(label.type, label.ref);
      final jsonLabelModel = json.encode(label.toJson());

      await _rawStore(entityKey, jsonLabelModel);
      await _rawStore(labelKey, jsonLabelModel);
    } catch (e) {
      debugPrint('$LabelStorageDatasource store: $e');
      rethrow;
    }
  }

  Future<List<LabelModel>> _fetch(Entity prefix, String entity) async {
    try {
      final anEntity = _encode(prefix, entity);
      final values = await _labelStorage.getStringList(anEntity) ?? [];

      return values
          .map(
            (v) => LabelModel.fromJson(json.decode(v) as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('$LabelStorageDatasource fetch: $e');
      rethrow;
    }
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

  /// Remove a label to all related entities
  Future<void> trash(String label) async {
    // Fetch all entities related to this label
    final entitiesLabeled = await fetchByLabel(label);

    // For each entity we remove that specific label
    for (final entity in entitiesLabeled) {
      final entityKey = _encode(entity.type, entity.ref);
      final jsonLabelModel = json.encode(entity.toJson());

      await _rawTrash(entityKey, jsonLabelModel);
    }

    // Then we delete the label entry
    final labelKey = _encode(Entity.label, label);
    await _labelStorage.remove(labelKey);
  }

  /// Remove a label from a single entity
  Future<void> trashByRef(LabelModel entity) async {
    final labelKey = _encode(Entity.label, entity.label);
    final entityKey = _encode(entity.type, entity.ref);
    final jsonLabelModel = json.encode(entity.toJson());

    _rawTrash(entityKey, jsonLabelModel);
    _rawTrash(labelKey, jsonLabelModel);
  }

  Future<void> trashAll() async => await _labelStorage.clear();

  Future<void> _rawStore(String key, String value) async {
    try {
      // Fetch all values related to this key
      final existingValues = await _labelStorage.getStringList(key) ?? [];

      if (!existingValues.contains(value)) {
        final updatedValues = [...existingValues, value];
        await _labelStorage.setStringList(key, updatedValues);
      }
    } catch (e) {
      debugPrint('$LabelStorageDatasource _rawStore: $e');
      rethrow;
    }
  }

  Future<void> _rawTrash(String key, String value) async {
    try {
      // Fetch all values related to this key
      final values = await _labelStorage.getStringList(key) ?? [];

      if (values.contains(value)) {
        values.remove(value);
        await _labelStorage.setStringList(key, values);
      }
    } catch (e) {
      debugPrint('$LabelStorageDatasource _rawTrash: $e');
      rethrow;
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
