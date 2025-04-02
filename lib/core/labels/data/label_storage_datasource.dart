import 'dart:convert';

import 'package:bb_mobile/core/labels/data/label_model.dart';
import 'package:bb_mobile/core/labels/domain/label_entity.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';

class LabelStorageDatasource {
  final KeyValueStorageDatasource<String> _mainLabelStorage;
  final KeyValueStorageDatasource<String> _refLabelStorage;

  LabelStorageDatasource({
    required KeyValueStorageDatasource<String> mainLabelStorage,
    required KeyValueStorageDatasource<String> refLabelStorage,
  })  : _mainLabelStorage = mainLabelStorage,
        _refLabelStorage = refLabelStorage;

  String _generateRefKey(String ref) {
    return 'ref_$ref';
  }

  String _generateMainKey(String label) {
    return 'label_$label';
  }

  Future<void> create(Label label) async {
    final labelModel = LabelModel.fromEntity(label);
    // update main storage
    final mainKey = _generateMainKey(labelModel.label);
    if (await _mainLabelStorage.hasValue(mainKey)) {
      final existingLabelsJson = await _mainLabelStorage.getValue(mainKey);
      List<LabelModel> existingLabels = [];

      try {
        final decoded = jsonDecode(existingLabelsJson!);
        if (decoded is List) {
          existingLabels = decoded
              .whereType<Map<String, dynamic>>()
              .map((item) => LabelModel.fromJson(item))
              .toList();
        }
      } catch (e) {
        // Handle JSON parsing error
        existingLabels = [];
      }

      final existingIndex = existingLabels.indexWhere(
        (l) => l.ref == labelModel.ref && l.type == labelModel.type,
      );

      if (existingIndex >= 0) {
        existingLabels[existingIndex] = labelModel;
      } else {
        existingLabels.add(labelModel);
      }
      await _mainLabelStorage.saveValue(
        key: mainKey,
        value: jsonEncode(existingLabels.map((l) => l.toJson()).toList()),
      );
    } else {
      await _mainLabelStorage.saveValue(
        key: mainKey,
        value: jsonEncode([labelModel.toJson()]),
      );
    }
    // Update ref storage
    final refKey = _generateRefKey(labelModel.ref);

    if (await _refLabelStorage.hasValue(refKey)) {
      final existingRefLabelsJson = await _refLabelStorage.getValue(refKey);
      List<LabelModel> existingRefLabels = [];

      try {
        final decoded = jsonDecode(existingRefLabelsJson!);
        if (decoded is Map<String, dynamic>) {
          existingRefLabels = [LabelModel.fromJson(decoded)];
        } else if (decoded is List) {
          existingRefLabels = decoded
              .whereType<Map<String, dynamic>>()
              .map((item) => LabelModel.fromJson(item))
              .toList();
        }
      } catch (e) {
        existingRefLabels = [];
      }

      final existingIndex = existingRefLabels.indexWhere(
        (l) => l.label == labelModel.label,
      );

      if (existingIndex >= 0) {
        existingRefLabels[existingIndex] = labelModel;
      } else {
        existingRefLabels.add(labelModel);
      }

      await _refLabelStorage.saveValue(
        key: refKey,
        value: jsonEncode(existingRefLabels.map((l) => l.toJson()).toList()),
      );
    } else {
      await _refLabelStorage.saveValue(
        key: refKey,
        value: jsonEncode([labelModel.toJson()]),
      );
    }
  }

  Future<List<LabelModel>?> readByLabel(String label) async {
    final mainKey = _generateMainKey(label);
    if (await _mainLabelStorage.hasValue(mainKey)) {
      final labelsJson = await _mainLabelStorage.getValue(mainKey);
      try {
        final decoded = jsonDecode(labelsJson!);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .map((item) => LabelModel.fromJson(item))
              .toList();
        }
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  Future<List<LabelModel>?> readByRef(String ref) async {
    final refKey = _generateRefKey(ref);

    if (await _refLabelStorage.hasValue(refKey)) {
      final labelsJson = await _refLabelStorage.getValue(refKey);
      try {
        final decoded = jsonDecode(labelsJson!);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .map((item) => LabelModel.fromJson(item))
              .toList();
        }
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  /// Reads all labels stored in the main storage
  /// Returns a list of all LabelModel objects across all keys
  Future<List<LabelModel>> readAll() async {
    final allLabels = <LabelModel>[];
    final allEntries = await _mainLabelStorage.getAll();

    for (final entry in allEntries.entries) {
      try {
        final decoded = jsonDecode(entry.value);
        if (decoded is List) {
          final labelsForKey = decoded
              .whereType<Map<String, dynamic>>()
              .map((item) => LabelModel.fromJson(item))
              .toList();

          allLabels.addAll(labelsForKey);
        }
      } catch (e) {
        continue;
      }
    }
    return allLabels;
  }

  Future<void> deleteAll() async {
    await _mainLabelStorage.deleteAll();
    await _refLabelStorage.deleteAll();
  }

  Future<void> deleteLabel(Label label) async {
    final labelModel = LabelModel.fromEntity(label);

    // Delete from main storage
    final mainKey = _generateMainKey(labelModel.label);
    if (await _mainLabelStorage.hasValue(mainKey)) {
      final labelsJson = await _mainLabelStorage.getValue(mainKey);
      try {
        final decoded = jsonDecode(labelsJson!);
        if (decoded is List) {
          final List<LabelModel> labels = decoded
              .whereType<Map<String, dynamic>>()
              .map((item) => LabelModel.fromJson(item))
              .toList();

          final initialLength = labels.length;
          labels.removeWhere(
            (l) => l.ref == labelModel.ref && l.type == labelModel.type,
          );

          if (labels.length < initialLength) {
            if (labels.isEmpty) {
              // If no labels left, delete the entry
              await _mainLabelStorage.deleteValue(mainKey);
            } else {
              await _mainLabelStorage.saveValue(
                key: mainKey,
                value: jsonEncode(labels.map((l) => l.toJson()).toList()),
              );
            }
          }
        }
      } catch (e) {
        rethrow;
      }
    }

    // Delete from ref storage
    final refKey = _generateRefKey(labelModel.ref);
    if (await _refLabelStorage.hasValue(refKey)) {
      final labelsJson = await _refLabelStorage.getValue(refKey);
      try {
        final decoded = jsonDecode(labelsJson!);
        if (decoded is List) {
          final List<LabelModel> labels = decoded
              .whereType<Map<String, dynamic>>()
              .map((item) => LabelModel.fromJson(item))
              .toList();

          final initialLength = labels.length;
          labels.removeWhere((l) => l.label == labelModel.label);

          if (labels.length < initialLength) {
            if (labels.isEmpty) {
              await _refLabelStorage.deleteValue(refKey);
            } else {
              await _refLabelStorage.saveValue(
                key: refKey,
                value: jsonEncode(labels.map((l) => l.toJson()).toList()),
              );
            }
          }
        }
      } catch (e) {
        rethrow;
      }
    }
  }
}
