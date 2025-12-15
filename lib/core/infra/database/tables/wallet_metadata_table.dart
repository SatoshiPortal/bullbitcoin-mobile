import 'package:bb_mobile/core/primitives/network/network.dart';
import 'package:drift/drift.dart';

@DataClassName('WalletMetadataRow')
class WalletMetadatas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get label => text().nullable()();
  BoolColumn get isDefault => boolean()();
  TextColumn get network => textEnum<Network>()();
  DateTimeColumn get mnemonicTestedAt => dateTime().nullable()();
  DateTimeColumn get encryptedVaultTestedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get birthday => dateTime().nullable()();
}
