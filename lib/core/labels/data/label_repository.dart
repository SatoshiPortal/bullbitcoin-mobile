import 'package:bb_mobile/core/labels/data/label_model_mapper.dart';
import 'package:bb_mobile/core/labels/data/labelable.dart';
import 'package:bb_mobile/core/labels/domain/label_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/entity/address.dart';
import 'package:bb_mobile/core/wallet/domain/entity/utxo.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_transaction.dart';
import 'package:drift/drift.dart';

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
    if (entity is Transaction) {
      return Entity.tx;
    } else if (entity is Address) {
      return Entity.address;
    } else if (entity is Utxo) {
      return Entity.output;
    }

    throw ArgumentError('Invalid type: $entity');
  }
}

class LabelRepository {
  final SqliteDatasource _sqlite;

  LabelRepository({required SqliteDatasource sqliteDatasource})
      : _sqlite = sqliteDatasource;

  Future<void> store<T extends Labelable>({
    required String label,
    required T entity,
    String? origin,
    bool? spendable,
  }) async {
    await _sqlite.managers.labels.create(
      (l) => l(
        label: label,
        type: Entity.fromLabelable(entity).name,
        ref: entity.toRef(),
        origin: Value(origin),
        spendable: Value(spendable),
      ),
    );
  }

  Future<List<Label>> fetchByLabel({required String label}) async {
    final labelModels =
        await _sqlite.managers.labels.filter((l) => l.label(label)).get();
    return labelModels.map((model) => model.toEntity()).toList();
  }

  Future<List<Label>> fetchByEntity<T extends Labelable>({
    required T entity,
  }) async {
    final labelModels = await _sqlite.managers.labels
        .filter((l) => l.ref(entity.toRef()))
        .get();
    return labelModels.map((model) => model.toEntity()).toList();
  }

  Future<void> trashByLabel({required String label}) async {
    await _sqlite.managers.labels.filter((l) => l.label(label)).delete();
  }

  Future<void> trashByEntity<T extends Labelable>({required T entity}) async {
    await _sqlite.managers.labels.filter((l) => l.ref(entity.toRef())).delete();
  }

  Future<void> trashOneLabel<T extends Labelable>({
    required T entity,
    required String label,
  }) async {
    await _sqlite.managers.labels
        .filter((l) => l.ref(entity.toRef()) & l.label(label))
        .delete();
  }

  Future<List<Label>> fetchAll() async {
    final labelModels = await _sqlite.managers.labels.get();
    return labelModels.map((model) => model.toEntity()).toList();
  }

  Future<void> trashAll() async {
    await _sqlite.delete(_sqlite.labels).go();
  }
}
