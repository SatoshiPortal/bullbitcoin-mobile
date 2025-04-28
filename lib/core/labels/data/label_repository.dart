import 'package:bb_mobile/core/labels/data/label_model_mapper.dart';
import 'package:bb_mobile/core/labels/domain/label_entity.dart';
import 'package:bb_mobile/core/labels/domain/labelable.dart';
import 'package:bb_mobile/core/storage/sqlite_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_input.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_output.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
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
    if (entity is WalletTransaction) {
      return Entity.tx;
    } else if (entity is WalletAddress) {
      return Entity.address;
    } else if (entity is WalletUtxo || entity is TransactionOutput) {
      return Entity.output;
    } else if (entity is TransactionInput) {
      return Entity.input;
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
        ref: entity.labelRef,
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
        .filter((l) => l.ref(entity.labelRef))
        .get();
    return labelModels.map((model) => model.toEntity()).toList();
  }

  Future<void> trashByLabel({required String label}) async {
    await _sqlite.managers.labels.filter((l) => l.label(label)).delete();
  }

  Future<void> trashByEntity<T extends Labelable>({required T entity}) async {
    await _sqlite.managers.labels
        .filter((l) => l.ref(entity.labelRef))
        .delete();
  }

  Future<void> trashOneLabel<T extends Labelable>({
    required T entity,
    required String label,
  }) async {
    await _sqlite.managers.labels
        .filter((l) => l.ref(entity.labelRef) & l.label(label))
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
