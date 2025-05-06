import 'package:bb_mobile/core/labels/domain/labelable.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_input.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_output.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:drift/drift.dart';

@DataClassName('LabelRow')
class Labels extends Table {
  TextColumn get label => text()();
  TextColumn get ref => text()();
  TextColumn get type => textEnum<LabelableEntity>()();
  TextColumn get origin => text().nullable()();
  BoolColumn get spendable => boolean().nullable()();

  @override
  Set<Column> get primaryKey => {label, ref};
}

enum LabelableEntity {
  tx,
  address,
  pubkey,
  input,
  output,
  xpub;

  static LabelableEntity from(String string) {
    switch (string) {
      case 'tx':
        return LabelableEntity.tx;
      case 'address':
        return LabelableEntity.address;
      case 'pubkey':
        return LabelableEntity.pubkey;
      case 'input':
        return LabelableEntity.input;
      case 'output':
        return LabelableEntity.output;
      case 'xpub':
        return LabelableEntity.xpub;
      default:
        throw ArgumentError('Invalid type: $string');
    }
  }

  static LabelableEntity fromLabelable(Labelable entity) {
    return switch (entity) {
      WalletTransaction() => LabelableEntity.tx,
      WalletAddress() => LabelableEntity.address,
      WalletUtxo() || TransactionOutput() => LabelableEntity.output,
      TransactionInput() => LabelableEntity.input,
      _ => throw ArgumentError('Invalid type: $entity'),
    };
  }
}
