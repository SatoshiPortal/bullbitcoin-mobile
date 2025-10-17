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
  bitbox02,
  coldcardQ,
  jade,
  keystone,
  krux,
  ledgerNanoSPlus,
  ledgerNanoX,
  ledgerFlex,
  ledgerStax,
  passport,
  seedsigner;

  static SignerDevice fromEntity(SignerDeviceEntity entity) => switch (entity) {
    SignerDeviceEntity.bitbox02 => SignerDevice.bitbox02,
    SignerDeviceEntity.coldcardQ => SignerDevice.coldcardQ,
    SignerDeviceEntity.jade => SignerDevice.jade,
    SignerDeviceEntity.keystone => SignerDevice.keystone,
    SignerDeviceEntity.krux => SignerDevice.krux,
    SignerDeviceEntity.ledgerNanoSPlus => SignerDevice.ledgerNanoSPlus,
    SignerDeviceEntity.ledgerNanoX => SignerDevice.ledgerNanoX,
    SignerDeviceEntity.ledgerFlex => SignerDevice.ledgerFlex,
    SignerDeviceEntity.ledgerStax => SignerDevice.ledgerStax,
    SignerDeviceEntity.passport => SignerDevice.passport,
    SignerDeviceEntity.seedsigner => SignerDevice.seedsigner,
  };

  SignerDeviceEntity toEntity() => switch (this) {
    SignerDevice.bitbox02 => SignerDeviceEntity.bitbox02,
    SignerDevice.coldcardQ => SignerDeviceEntity.coldcardQ,
    SignerDevice.jade => SignerDeviceEntity.jade,
    SignerDevice.keystone => SignerDeviceEntity.keystone,
    SignerDevice.krux => SignerDeviceEntity.krux,
    SignerDevice.ledgerNanoSPlus => SignerDeviceEntity.ledgerNanoSPlus,
    SignerDevice.ledgerNanoX => SignerDeviceEntity.ledgerNanoX,
    SignerDevice.ledgerFlex => SignerDeviceEntity.ledgerFlex,
    SignerDevice.ledgerStax => SignerDeviceEntity.ledgerStax,
    SignerDevice.passport => SignerDeviceEntity.passport,
    SignerDevice.seedsigner => SignerDeviceEntity.seedsigner,
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
  DateTimeColumn get birthday => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
