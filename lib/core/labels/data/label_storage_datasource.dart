import 'package:bb_mobile/core/labels/data/label_model.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/shared_preferences_datasource_impl.dart';

enum Prefix {
  label,
  tx,
  address,
  pubkey,
  input,
  output,
  xpub;

  static Prefix from(String string) {
    switch (string) {
      case 'label':
        return Prefix.label;
      case 'tx':
        return Prefix.tx;
      case 'address':
        return Prefix.address;
      case 'pubkey':
        return Prefix.pubkey;
      case 'input':
        return Prefix.input;
      case 'output':
        return Prefix.output;
      case 'xpub':
        return Prefix.xpub;
      default:
        throw ArgumentError('Invalid entity type: $string');
    }
  }

  static String get separator => '_';
}

class LabelStorageDatasource {
  final SharedPreferencesDatasourceImpl _labelStorage;

  LabelStorageDatasource({
    required SharedPreferencesDatasourceImpl labelStorage,
  }) : _labelStorage = labelStorage;

  String _encodePrefixEntity(Prefix prefix, String id) {
    return '${prefix.name}${Prefix.separator}$id';
  }

  (Prefix, String) _decodePrefix(String entityWithPrefix) {
    final parts = entityWithPrefix.split(Prefix.separator);
    final prefix = Prefix.from(parts.first);
    final entity = parts.last;
    return (prefix, entity);
  }

  Future<void> store(LabelModel label) async {
    final aLabel = _encodePrefixEntity(Prefix.label, label.label);
    final anEntity = _encodePrefixEntity(Prefix.from(label.type), label.ref);

    _storeOrUpdate(anEntity, aLabel);
    _storeOrUpdate(aLabel, anEntity);
  }

  Future<List<LabelModel>> fetchByLabel(String label) async {
    final anEntity = _encodePrefixEntity(Prefix.label, label);
    final values = await _labelStorage.getValues(anEntity) ?? [];

    final result = <LabelModel>[];
    for (final value in values) {
      final (prefix, entity) = _decodePrefix(value);
      result.add(LabelModel(type: prefix.name, ref: entity, label: label));
    }

    return result;
  }

  Future<List<LabelModel>> fetchByEntity(Prefix prefix, String entity) async {
    final anEntity = _encodePrefixEntity(prefix, entity);
    final values = await _labelStorage.getValues(anEntity) ?? [];

    final result = <LabelModel>[];
    for (final value in values) {
      final (_, label) = _decodePrefix(value);
      result.add(LabelModel(type: prefix.name, ref: entity, label: label));
    }

    return result;
  }

  /// Reads all labels stored in the main storage
  /// Returns a list of all LabelModel objects across all keys
  /// O(k + e), where k = number of keys and e = total number of entities across all keys
  Future<List<LabelModel>> fetchAll() async {
    final all = await _labelStorage.getAll();
    final labels = all.keys.where((k) => k.startsWith(Prefix.label.name));

    final result = <LabelModel>[];
    for (final label in labels) {
      final entities = await _labelStorage.getValues(label) ?? [];

      for (final entityWithPrefix in entities.toSet()) {
        final (prefix, entity) = _decodePrefix(entityWithPrefix);
        result.add(LabelModel(type: prefix.name, ref: entity, label: label));
      }
    }
    return result;
  }

  Future<void> trash(LabelModel label) async {
    final aLabel = _encodePrefixEntity(Prefix.label, label.label);

    // Fetch all entities related to this label
    final entities = await _labelStorage.getValues(aLabel) ?? [];

    // Delete each entity associated with this label
    for (final e in entities) {
      _labelStorage.deleteValue(e);
    }
  }

  Future<void> trashAll() async => await _labelStorage.deleteAll();

  Future<void> _storeOrUpdate(String key, String value) async {
    // Fetch all values related to this key
    final existingValues = await _labelStorage.getValues(key) ?? [];

    if (!existingValues.contains(value)) {
      final updatedValues = [...existingValues, value];
      await _labelStorage.saveValues(key, updatedValues);
    }
  }
}
