import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:drift/drift.dart';

enum Signer {
  local,
  remote,
  none;

  static Signer fromName(String name) {
    return Signer.values.firstWhere((source) => source.name == name);
  }

  String get displayName =>
      StringFormatting.camelCaseToTitleCase(name, separator: ' ');
}

enum SignerDevice {
  coldcardQ;

  String get displayName =>
      StringFormatting.camelCaseToTitleCase(name, separator: ' ');
}

@DataClassName('WalletMetadataRow')
class WalletMetadatas extends Table {
  TextColumn get id => text()();
  TextColumn get masterFingerprint => text()();
  TextColumn get xpubFingerprint => text()();
  BoolColumn get isEncryptedVaultTested => boolean()();
  BoolColumn get isPhysicalBackupTested => boolean()();
  IntColumn get latestEncryptedBackup => integer().nullable()();
  IntColumn get latestPhysicalBackup => integer().nullable()();
  TextColumn get xpub => text()();
  TextColumn get externalPublicDescriptor => text()();
  TextColumn get internalPublicDescriptor => text()();
  TextColumn get signer => text()();
  TextColumn get signerDevice => textEnum<SignerDevice>().nullable()();
  BoolColumn get isDefault => boolean()();
  TextColumn get label => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
