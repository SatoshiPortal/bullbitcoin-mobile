import 'package:drift/drift.dart';

enum LabelType {
  tx,
  address,
  pubkey,
  input,
  output,
  xpub;

  static LabelType fromString(String string) {
    switch (string) {
      case 'tx':
        return LabelType.tx;
      case 'address':
        return LabelType.address;
      case 'pubkey':
        return LabelType.pubkey;
      case 'input':
        return LabelType.input;
      case 'output':
        return LabelType.output;
      case 'xpub':
        return LabelType.xpub;
      default:
        throw ArgumentError('Invalid type: $string');
    }
  }
}

@DataClassName('LabelRow')
class Labels extends Table {
  TextColumn get label => text()();
  TextColumn get ref => text()();
  TextColumn get type => textEnum<LabelType>()();
  TextColumn get origin => text().nullable()();
  BoolColumn get spendable => boolean().nullable()();

  @override
  Set<Column> get primaryKey => {label, ref};
}
