import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
// Drift resolves the referenced table from this import when generating the
// raw foreign-key constraints.
// ignore: unused_import
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:drift/drift.dart';

enum Signer {
  local,
  remote,
  none;

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

  static SignerDevice fromEntity(SignerDeviceEntity entity) => switch (entity) {
    SignerDeviceEntity.bitbox02 => SignerDevice.bitbox02,
    SignerDeviceEntity.coldcardQ => SignerDevice.coldcardQ,
    SignerDeviceEntity.coldcardMk4 => SignerDevice.coldcardMk4,
    SignerDeviceEntity.jade => SignerDevice.jade,
    SignerDeviceEntity.keystone => SignerDevice.keystone,
    SignerDeviceEntity.krux => SignerDevice.krux,
    SignerDeviceEntity.ledgerNanoSPlus => SignerDevice.ledgerNanoSPlus,
    SignerDeviceEntity.ledgerNanoX => SignerDevice.ledgerNanoX,
    SignerDeviceEntity.ledgerFlex => SignerDevice.ledgerFlex,
    SignerDeviceEntity.ledgerStax => SignerDevice.ledgerStax,
    SignerDeviceEntity.passport => SignerDevice.passport,
    SignerDeviceEntity.seedsigner => SignerDevice.seedsigner,
    SignerDeviceEntity.specter => SignerDevice.specter,
  };

  SignerDeviceEntity toEntity() => switch (this) {
    SignerDevice.bitbox02 => SignerDeviceEntity.bitbox02,
    SignerDevice.coldcardQ => SignerDeviceEntity.coldcardQ,
    SignerDevice.coldcardMk4 => SignerDeviceEntity.coldcardMk4,
    SignerDevice.jade => SignerDeviceEntity.jade,
    SignerDevice.keystone => SignerDeviceEntity.keystone,
    SignerDevice.krux => SignerDeviceEntity.krux,
    SignerDevice.ledgerNanoSPlus => SignerDeviceEntity.ledgerNanoSPlus,
    SignerDevice.ledgerNanoX => SignerDeviceEntity.ledgerNanoX,
    SignerDevice.ledgerFlex => SignerDeviceEntity.ledgerFlex,
    SignerDevice.ledgerStax => SignerDeviceEntity.ledgerStax,
    SignerDevice.passport => SignerDeviceEntity.passport,
    SignerDevice.seedsigner => SignerDeviceEntity.seedsigner,
    SignerDevice.specter => SignerDeviceEntity.specter,
  };
}

@DataClassName('WalletSignerRow')
class WalletSigners extends Table {
  TextColumn get walletId => text()();
  TextColumn get id => text()();
  IntColumn get position => integer()();
  TextColumn get signer => textEnum<Signer>()();
  TextColumn get signerDevice => textEnum<SignerDevice>().nullable()();
  TextColumn get registrationName => text().nullable()();
  TextColumn get localSeedFingerprint => text().nullable()();

  @override
  Set<Column> get primaryKey => {walletId, id};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY(wallet_id) REFERENCES wallet_metadatas(id) ON DELETE CASCADE',
    'UNIQUE(wallet_id, position)',
  ];
}

@DataClassName('WalletDescriptorKeyRow')
class WalletDescriptorKeys extends Table {
  TextColumn get walletId => text()();
  TextColumn get id => text()();
  IntColumn get position => integer()();
  TextColumn get signerId => text()();
  TextColumn get masterFingerprint => text()();
  TextColumn get xpubFingerprint => text()();
  TextColumn get xpub => text()();
  TextColumn get derivationPath => text().nullable()();
  TextColumn get descriptorPath => text().withDefault(const Constant(''))();
  BoolColumn get requiresPassphrase =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {walletId, id};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY(wallet_id) REFERENCES wallet_metadatas(id) ON DELETE CASCADE',
    'FOREIGN KEY(wallet_id, signer_id) REFERENCES wallet_signers(wallet_id, id) ON DELETE CASCADE',
    'UNIQUE(wallet_id, position)',
  ];
}
