import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:drift/drift.dart';

enum Signer {
  local,
  remote,
  none;

  static Signer fromName(String name) {
    return Signer.values.firstWhere((source) => source.name == name);
  }

  static Signer fromEntity(SignerEntity entity) => switch (entity) {
    SignerEntity.local => Signer.local,
    SignerEntity.remote => Signer.remote,
    SignerEntity.none => Signer.none,
  };

  SignerEntity toEntity() => switch (this) {
    Signer.local => SignerEntity.local,
    Signer.remote => SignerEntity.remote,
    Signer.none => SignerEntity.none,
  };
}

enum SignerDevice {
  coldcardQ;

  static SignerDevice fromEntity(SignerDeviceEntity entity) => switch (entity) {
    SignerDeviceEntity.coldcardQ => SignerDevice.coldcardQ,
  };

  SignerDeviceEntity toEntity() => switch (this) {
    SignerDevice.coldcardQ => SignerDeviceEntity.coldcardQ,
  };
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
