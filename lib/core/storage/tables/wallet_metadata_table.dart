import 'package:signers/signers.dart' as signers;
import 'package:primitives/primitives.dart' show SignerEntity;
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
  coldcardMk4,
  jade,
  keystone,
  krux,
  ledgerNanoSPlus,
  ledgerNanoX,
  ledgerFlex,
  ledgerStax,
  passport,
  seedsigner,
  specter;

  static SignerDevice fromEntity(signers.SignerDevice entity) =>
      switch (entity) {
        signers.SignerDevice.bitbox02 => SignerDevice.bitbox02,
        signers.SignerDevice.coldcardQ => SignerDevice.coldcardQ,
        signers.SignerDevice.coldcardMk4 => SignerDevice.coldcardMk4,
        signers.SignerDevice.jade => SignerDevice.jade,
        signers.SignerDevice.keystone => SignerDevice.keystone,
        signers.SignerDevice.krux => SignerDevice.krux,
        signers.SignerDevice.ledgerNanoSPlus => SignerDevice.ledgerNanoSPlus,
        signers.SignerDevice.ledgerNanoX => SignerDevice.ledgerNanoX,
        signers.SignerDevice.ledgerFlex => SignerDevice.ledgerFlex,
        signers.SignerDevice.ledgerStax => SignerDevice.ledgerStax,
        signers.SignerDevice.passport => SignerDevice.passport,
        signers.SignerDevice.seedsigner => SignerDevice.seedsigner,
        signers.SignerDevice.specter => SignerDevice.specter,
      };

  signers.SignerDevice toEntity() => switch (this) {
    SignerDevice.bitbox02 => signers.SignerDevice.bitbox02,
    SignerDevice.coldcardQ => signers.SignerDevice.coldcardQ,
    SignerDevice.coldcardMk4 => signers.SignerDevice.coldcardMk4,
    SignerDevice.jade => signers.SignerDevice.jade,
    SignerDevice.keystone => signers.SignerDevice.keystone,
    SignerDevice.krux => signers.SignerDevice.krux,
    SignerDevice.ledgerNanoSPlus => signers.SignerDevice.ledgerNanoSPlus,
    SignerDevice.ledgerNanoX => signers.SignerDevice.ledgerNanoX,
    SignerDevice.ledgerFlex => signers.SignerDevice.ledgerFlex,
    SignerDevice.ledgerStax => signers.SignerDevice.ledgerStax,
    SignerDevice.passport => signers.SignerDevice.passport,
    SignerDevice.seedsigner => signers.SignerDevice.seedsigner,
    SignerDevice.specter => signers.SignerDevice.specter,
  };
}

@DataClassName('WalletMetadataRow')
class WalletMetadatas extends Table {
  TextColumn get id => text()();
  TextColumn get network => text().withDefault(const Constant('unresolved'))();
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
