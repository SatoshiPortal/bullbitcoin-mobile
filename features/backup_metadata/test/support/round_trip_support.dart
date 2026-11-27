import 'package:backup_metadata/backup_metadata.dart';
import 'package:backup_metadata/setup.dart' hide MetadataBackupInventory;
import 'package:backup_metadata/src/data/backup_metadata_repository_impl.dart';
import 'package:backup_metadata/src/data/metadata_backup_inventory.dart' as bm;
import 'package:backup_metadata/src/domain/usecases/apply_restore_usecase.dart';
import 'package:backup_metadata/src/domain/usecases/preview_restore_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labels/backup.dart';
import 'package:labels/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/metadata_backup.dart';
import 'package:secrets/storage.dart' show RegisteredWallet;

import 'fake_backup_secrets.dart' show testJournalKey;
import 'memory_backup_storage.dart';
import 'open_inventory.dart';

const seedWords =
    'abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon abandon about';
const watchWords =
    'legal winner thank year wave sausage worth useful '
    'legal winner thank yellow';
const txid = 'aa00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa00';

/// Labels with the freeze semantics the engine relies on, in memory. The
/// durable Labels owner has its own tests; this keeps the round trip about
/// what travels and what each owner is asked to apply.
final class MemoryLabels implements BackupLabelsPort {
  final Map<String, (BackupLabelRecord, String)> entries = {};
  final Set<String> frozen = {};
  bool failApply = false;
  int appliedRuns = 0;

  void add(BackupLabelRecord record, String walletId) =>
      entries['${record.chain.name}|${record.type.name}|${record.ref}'] = (
        record,
        walletId,
      );

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<Result<LabelsSnapshot, BackupMetadataFailure>> capture(
    BackupSessionRef session,
    BackupGroup group,
  ) async {
    final wallets = {...group.bitcoinWalletIds, ...group.liquidWalletIds};
    return Ok(
      LabelsSnapshot(
        records: [
          for (final (record, wallet) in entries.values)
            if (wallets.contains(wallet)) record,
        ],
        unattributedCount: 0,
        skippedCount: 0,
      ),
    );
  }

  @override
  Future<Result<MergePlan, BackupMetadataFailure>> preview(
    BackupSessionRef session,
    BackupGroup group,
    LabelsSnapshot incoming,
  ) async {
    final additions = <BackupLabelRecord>[];
    var unchanged = 0;
    for (final record in incoming.records) {
      final key = '${record.chain.name}|${record.type.name}|${record.ref}';
      if (entries.containsKey(key)) {
        unchanged++;
      } else {
        additions.add(record);
      }
    }
    return Ok(
      MergePlan(
        groupId: group.id,
        baseDigest: 'base',
        additions: additions,
        unchanged: unchanged,
        conflicts: const [],
        freezes: [
          for (final record in incoming.records)
            if (record.spendable == false && record.walletId != null)
              FreezeRequest(walletId: record.walletId!, outpoint: record.ref),
        ],
      ),
    );
  }

  @override
  Future<Result<ApplyReport, BackupMetadataFailure>> apply(
    BackupSessionRef session,
    MergePlan plan,
    MergeChoices choices,
  ) async {
    if (failApply) return const Err(BackupMetadataUnexpectedFailure());
    appliedRuns++;
    for (final record in plan.additions) {
      add(record, record.walletId ?? 'unattributed');
    }
    frozen.addAll(plan.freezes.map((freeze) => freeze.outpoint));
    return Ok(
      ApplyReport(
        labelsApplied: plan.additions.length,
        labelsUnchanged: plan.unchanged,
        labelsRejected: const {},
        freezes: {
          for (final freeze in plan.freezes) freeze: FreezeOutcome.applied,
        },
      ),
    );
  }
}

/// The engine of one phone over its real inventory and journal.
final class Engine {
  final Phone phone;
  final MemoryBackupStorage storage;
  final MemoryLabels labels = MemoryLabels();

  /// The real label backup engine, when a test asks for it.
  final LabelBackupsFixture? real;
  late final MetadataBackupSecrets secretsPort = MetadataBackupSecrets(
    phone.inventory,
  );
  late final BackupMetadataStore store = BackupMetadataStore(
    path: phone.journalPath,
    key: testJournalKey,
  );
  late final bm.MetadataBackupInventory inventoryPort =
      bm.MetadataBackupInventory(
        wallets: () => phone.inventory.metadataBackupWallets(phone.secrets),
        store: store,
        secrets: secretsPort,
        hasSilentPaymentsWallet: () async => false,
        defaultBitcoinWalletLabel: 'Default',
        unnamedWalletLabel: 'Unnamed',
        backupVerified: (_, _) async => true,
      );
  late final BackupLabelsPort labelsPort = switch (real) {
    final fixture? => MetadataBackupLabels(
      inventory: inventoryPort,
      backups: fixture.backups,
    ),
    null => labels,
  };
  late final BackupMetadataRepositoryImpl repository =
      BackupMetadataRepositoryImpl(
        store: store,
        inventory: inventoryPort,
        labels: labelsPort,
        secrets: secretsPort,
        codec: const Bip138BackupMetadataCodec(),
        storages: [storage],
      );

  Engine(this.phone, this.storage, {this.real});

  Future<List<BackupGroup>> groups() async {
    // The foreground prepares the journal before the inventory reads it.
    await store.locked((_) async {}, view: 'all');
    return valueOf(await inventoryPort.read()).groups;
  }

  Future<void> backUpEverything() async {
    final ids = {for (final group in await groups()) group.id};
    valueOf(
      await repository.configure(
        destination: storage.destination,
        groups: ids,
        deleteOwnedFiles: false,
      ),
    );
    final status = valueOf(await repository.run());
    for (final group in status.groups) {
      expect(group.failure, isNull, reason: '${group.actionNeeded}');
      expect(group.pendingChanges, isFalse);
    }
  }

  Future<RestoreReport> restore(
    DiscoveredBackup backup, {
    bool expectPartial = false,
  }) async {
    final plan = valueOf(
      await PreviewRestoreUsecase(labelsPort).execute(backup),
    );
    final result = await ApplyRestoreUsecase(
      labelsPort,
      secretsPort,
    ).execute(backup, plan, MergeChoices({}));
    final report = valueOf(result);
    expect(report.isPartial, expectPartial);
    return report;
  }
}

RegisteredWallet registeredWallet({
  required String id,
  required String network,
  required String external,
  required String internal,
  String? parent,
  String signer = 'local',
  String? label,
  String? birthday,
  bool isDefault = false,
}) => RegisteredWallet(
  id: id,
  secretFingerprint: parent,
  masterFingerprint: parent ?? '0a1b2c3d',
  signer: signer,
  network: network,
  xpub: 'public-marker',
  externalDescriptor: external,
  internalDescriptor: internal,
  label: label,
  birthday: birthday,
  isDefault: isDefault,
);
