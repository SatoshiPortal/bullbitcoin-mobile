import 'package:bb_mobile/core/labels/data/label_model.dart';
import 'package:bb_mobile/core/labels/domain/labelable.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_input.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_output.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:drift/drift.dart';

enum Entity {
  tx,
  address,
  pubkey,
  input,
  output,
  xpub;

  static Entity from(String string) {
    switch (string) {
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
    return switch (entity) {
      WalletTransaction() => Entity.tx,
      WalletAddress() => Entity.address,
      WalletUtxo() || TransactionOutput() => Entity.output,
      TransactionInput() => Entity.input,
      _ => throw ArgumentError('Invalid type: $entity'),
    };
  }
}

class LabelDatasource {
  final SqliteDatabase _sqlite;

  LabelDatasource({required SqliteDatabase sqlite}) : _sqlite = sqlite;

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

  Future<List<LabelModel>> fetchByLabel({required String label}) async {
    final labelModels =
        await _sqlite.managers.labels.filter((l) => l.label(label)).get();
    return labelModels.map((row) => LabelModelMapper.fromSqlite(row)).toList();
  }

  Future<List<LabelModel>> fetchByEntity<T extends Labelable>({
    required T entity,
  }) async {
    final labelModels =
        await _sqlite.managers.labels
            .filter((l) => l.ref(entity.labelRef))
            .get();
    return labelModels.map((row) => LabelModelMapper.fromSqlite(row)).toList();
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

  Future<List<LabelModel>> fetchAll() async {
    final labelModels = await _sqlite.managers.labels.get();
    return labelModels.map((row) => LabelModelMapper.fromSqlite(row)).toList();
  }

  Future<void> trashAll() async {
    await _sqlite.delete(_sqlite.labels).go();
  }
}
