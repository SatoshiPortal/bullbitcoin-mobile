import 'dart:convert';

import 'package:bb_mobile/core/labels/data/label_model.dart';
import 'package:bb_mobile/core/labels/domain/label_entity.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';

class LabelStorageDatasource {
  final KeyValueStorageDatasource<String> _labelStorage;

  LabelStorageDatasource({
    required KeyValueStorageDatasource<String> labelStorage,
  }) : _labelStorage = labelStorage;

  Future<void> create(Label label) async {
    final labelModel = LabelModel.fromEntity(label);
    final key = _generateKey(labelModel);

    final exists = await _labelStorage.hasValue(key);
    if (exists) {
      return;
    }

    final labelJsonMap = labelModel.toJson();
    final jsonString = jsonEncode(labelJsonMap);
    await _labelStorage.saveValue(key: key, value: jsonString);
  }

  String _generateKey(LabelModel labelModel) {
    return '${labelModel.type}_${labelModel.ref}_${labelModel.label}';
  }

  Future<List<Label>?> readAll() async {
    final allEntries = await _labelStorage.getAll();
    final labels = <Label>[];

    for (final jsonString in allEntries.values) {
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final labelModel = LabelModel.fromJson(jsonMap);
      labels.add(labelModel.toEntity());
    }
    if (labels.isEmpty) {
      return null;
    }
    return labels;
  }

  Future<List<Label>?> readByRef(String ref) async {
    final allEntries = await _labelStorage.getAll();
    final labels = <Label>[];

    for (final entry in allEntries.entries) {
      if (entry.key.contains('_$ref' + '_')) {
        final jsonMap = jsonDecode(entry.value) as Map<String, dynamic>;
        final labelModel = LabelModel.fromJson(jsonMap);
        labels.add(labelModel.toEntity());
      }
    }
    if (labels.isEmpty) {
      return null;
    }
    return labels;
  }

  Future<List<Label>?> readByType(LabelType type) async {
    final typeStr = type.value;
    final allEntries = await _labelStorage.getAll();
    final labels = <Label>[];

    for (final entry in allEntries.entries) {
      if (entry.key.startsWith('${typeStr}_')) {
        final jsonMap = jsonDecode(entry.value) as Map<String, dynamic>;
        final labelModel = LabelModel.fromJson(jsonMap);
        labels.add(labelModel.toEntity());
      }
    }
    if (labels.isEmpty) {
      return null;
    }
    return labels;
  }

  Future<List<Label>?> readByTypeAndRef(
    LabelType type,
    String ref,
  ) async {
    final typeStr = type.value;
    final allEntries = await _labelStorage.getAll();
    final labels = <Label>[];

    for (final entry in allEntries.entries) {
      final key = entry.key;
      if (key.startsWith('${typeStr}_$ref' + '_')) {
        final jsonMap = jsonDecode(entry.value) as Map<String, dynamic>;
        final labelModel = LabelModel.fromJson(jsonMap);
        labels.add(labelModel.toEntity());
      }
    }
    if (labels.isEmpty) {
      return null;
    }
    return labels;
  }

  Future<void> deleteAllRefsWithLabel(Label label) async {
    final labelModel = LabelModel.fromEntity(label);
    final key = _generateKey(labelModel);
    await _labelStorage.deleteValue(key);
  }

  Future<void> deleteLabelForRef(
    String label,
    String ref,
    LabelType type,
  ) async {
    final typeStr = type.value;
    final allEntries = await _labelStorage.getAll();

    for (final key in allEntries.keys) {
      if (key.startsWith('${typeStr}_$ref' + '_')) {
        await _labelStorage.deleteValue(key);
      }
    }
  }

  Future<void> deleteAll() async {
    await _labelStorage.deleteAll();
  }
}
