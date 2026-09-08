import 'package:drift/drift.dart';

@DataClassName('BullVaultRecordModel')
class BullVaultRecords extends Table {
  TextColumn get walletId => text()();
  TextColumn get lineageId => text()();
  IntColumn get vaultGeneration => integer()();
  IntColumn get mobileAccount => integer().nullable()();
  TextColumn get mobileSeedFingerprint => text().nullable()();
  BoolColumn get mobilePassphraseRequired =>
      boolean().withDefault(const Constant(false))();
  IntColumn get birthHeight => integer().nullable()();
  TextColumn get recoveryPackage => text()();
  TextColumn get previousVaultId => text().nullable()();
  TextColumn get successorWalletId => text().nullable()();
  TextColumn get status => text()();
  BoolColumn get hardwareSetupComplete => boolean()();
  BoolColumn get hardwareSetupDeferred => boolean()();
  TextColumn get completedHardwareSignerIdsJson => text()();
  BoolColumn get recoveryPackageConfirmed => boolean()();
  BoolColumn get mobileBackupDeferred => boolean()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {walletId};

  @override
  List<Set<Column>> get uniqueKeys => [
    {lineageId, vaultGeneration},
  ];
}

class BullVaultGenerationReservations extends Table {
  TextColumn get lineageId => text()();
  IntColumn get generation => integer()();

  @override
  Set<Column> get primaryKey => {lineageId, generation};
}
