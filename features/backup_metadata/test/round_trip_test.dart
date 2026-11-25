import 'dart:convert';
import 'dart:io';

import 'package:backup_metadata/backup_metadata.dart';
import 'package:backup_metadata/setup.dart' hide MetadataBackupInventory;
import 'package:backup_metadata/src/data/backup_metadata_repository_impl.dart';
import 'package:backup_metadata/src/data/metadata_backup_inventory.dart' as bm;
import 'package:backup_metadata/src/domain/usecases/apply_restore_usecase.dart';
import 'package:backup_metadata/src/domain/usecases/preview_restore_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labels/backup.dart';
import 'package:primitives/primitives.dart';
import 'package:rust_bindings/rust_bindings.dart';
import 'package:secrets/metadata_backup.dart';
import 'package:secrets/secrets.dart' show Language, WalletSigner;
import 'package:secrets/storage.dart' show RegisteredWallet;

import 'support/fake_backup_secrets.dart' show testJournalKey;
import 'support/memory_backup_storage.dart';
import 'support/open_inventory.dart';

const _seedWords =
    'abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon abandon about';
const _watchWords =
    'legal winner thank year wave sausage worth useful '
    'legal winner thank yellow';
const _txid =
    'aa00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa00';

/// Labels with the freeze semantics the engine relies on, in memory. The
/// durable Labels owner has its own tests; this keeps the round trip about
/// what travels and what each owner is asked to apply.
final class _MemoryLabels implements BackupLabelsPort {
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
final class _Engine {
  final Phone phone;
  final MemoryBackupStorage storage;
  final _MemoryLabels labels = _MemoryLabels();
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
  late final BackupMetadataRepositoryImpl repository =
      BackupMetadataRepositoryImpl(
        store: store,
        inventory: inventoryPort,
        labels: labels,
        secrets: secretsPort,
        codec: const Bip138BackupMetadataCodec(),
        storages: [storage],
      );

  _Engine(this.phone, this.storage);

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
      await PreviewRestoreUsecase(labels, secretsPort).execute(backup),
    );
    final result = await ApplyRestoreUsecase(
      labels,
      secretsPort,
    ).execute(backup, plan, MergeChoices({}));
    final report = valueOf(result);
    expect(report.isPartial, expectPartial);
    return report;
  }
}

RegisteredWallet _wallet({
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(BullSdk.init);

  late Directory root;
  late MemoryBackupStorage storage;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('d72-round-trip');
    storage = MemoryBackupStorage();
  });

  tearDown(() async => root.delete(recursive: true));

  Future<Phone> phone(String name) async {
    final directory = Directory('${root.path}/$name')..createSync();
    return Phone.open(directory);
  }

  Future<({String external, String internal})> descriptorsOf(
    Phone p,
    String words,
  ) async {
    final all = valueOf(
      await p.secrets.preview.bitcoinDescriptors(
        words: words.split(' '),
        language: Language.english,
        network: BitcoinNetwork.testnet,
        scriptTypes: {ScriptType.bip84},
      ),
    );
    return all[ScriptType.bip84]!;
  }

  /// Phone A: a seed wallet with labels, a freeze and a BIP85 registry with
  /// gaps and revocations, and a watch-only account with its own labels.
  Future<
    ({
      _Engine engine,
      String seedWalletId,
      String watchWalletId,
      ({String external, String internal}) seed,
      ({String external, String internal}) watch,
    })
  >
  sourcePhone() async {
    final a = await phone('a');
    final secret = valueOf(
      await a.secrets.import(
        words: _seedWords.split(' '),
        language: Language.english,
      ),
    );
    final seed = await descriptorsOf(a, _seedWords);
    final watch = await descriptorsOf(a, _watchWords);
    final seedId = 'wpkh([${secret.id.hex}/84h/1h/0h])';
    const watchId = 'wpkh([0a1b2c3d/84h/1h/0h])';
    valueOf(
      await a.inventory.registerWallet(
        _wallet(
          id: seedId,
          network: 'bitcoinTestnet',
          external: seed.external,
          internal: seed.internal,
          parent: secret.id.hex,
          label: 'Main',
          birthday: '2026-01-02T00:00:00.000Z',
          isDefault: true,
        ),
      ),
    );
    valueOf(
      await a.inventory.registerWallet(
        _wallet(
          id: watchId,
          network: 'bitcoinTestnet',
          external: watch.external,
          internal: watch.internal,
          signer: 'remote',
          label: 'Cold storage',
          birthday: '2026-03-04T00:00:00.000Z',
        ),
      ),
    );
    // Children 0, 1 (inactive) and 2 (revoked); then a gap up to 9.
    final children = [
      for (var i = 0; i < 3; i++)
        valueOf(
          await a.inventory.reserveHexDerivation(
            parent: secret.id,
            length: 32,
            alias: 'child $i',
          ),
        ),
    ];
    valueOf(await a.inventory.setDerivationActive(children[2], active: false));
    valueOf(
      await a.inventory.mergeDerivationArchive(
        parent: secret.id,
        records: [
          RecordedDerivation(
            path: "128169'/32'/9'",
            parentFingerprint: secret.id.hex,
            application: 'hex',
            status: 'active',
            alias: 'after the gap',
          ),
        ],
      ),
    );

    final engine = _Engine(a, storage);
    engine.labels
      ..add(
        BackupLabelRecord(
          chain: BackupLabelChain.bitcoin,
          type: BackupLabelType.tx,
          ref: _txid,
          label: 'rent',
          walletId: seedId,
        ),
        seedId,
      )
      ..add(
        BackupLabelRecord(
          chain: BackupLabelChain.bitcoin,
          type: BackupLabelType.output,
          ref: '$_txid:1',
          spendable: false,
          walletId: seedId,
        ),
        seedId,
      )
      ..add(
        BackupLabelRecord(
          chain: BackupLabelChain.bitcoin,
          type: BackupLabelType.addr,
          ref: 'tb1qcoldaddress',
          label: 'cold deposit',
          walletId: watchId,
        ),
        watchId,
      );
    await engine.backUpEverything();
    expect(storage.created, 2);
    return (
      engine: engine,
      seedWalletId: seedId,
      watchWalletId: watchId,
      seed: seed,
      watch: watch,
    );
  }

  /// Phone B: new inventory and new journal. The user re-imports the seed and
  /// the public account, which arrive with no label and no birthday.
  Future<_Engine> freshPhone({
    required ({String external, String internal}) seed,
    required ({String external, String internal}) watch,
    String watchId = 'wpkh([99999999/84h/1h/0h])',
  }) async {
    final b = await phone('b');
    final secret = valueOf(
      await b.secrets.import(
        words: _seedWords.split(' '),
        language: Language.english,
      ),
    );
    valueOf(
      await b.inventory.registerWallet(
        _wallet(
          id: 'wpkh([${secret.id.hex}/84h/1h/0h])',
          network: 'bitcoinTestnet',
          external: seed.external,
          internal: seed.internal,
          parent: secret.id.hex,
          isDefault: true,
        ),
      ),
    );
    valueOf(
      await b.inventory.registerWallet(
        _wallet(
          id: watchId,
          network: 'bitcoinTestnet',
          external: watch.external,
          internal: watch.internal,
          signer: 'remote',
        ),
      ),
    );
    return _Engine(b, storage);
  }

  Future<List<DiscoveredBackup>> discover(_Engine engine) async =>
      valueOf(await engine.repository.discover(storage.destination));

  test(
    'D100: a backup produced on one phone restores on a fresh one',
    () async {
      final a = await sourcePhone();
      final b = await freshPhone(seed: a.seed, watch: a.watch);

      final backups = await discover(b);
      expect(backups, hasLength(2));
      final seedBackup = backups.singleWhere(
        (backup) => !backup.group.isWatchOnly,
      );
      final watchBackup = backups.singleWhere(
        (backup) => backup.group.isWatchOnly,
      );
      expect(seedBackup.scope, 'all');

      final seedReport = await b.restore(seedBackup);
      final watchReport = await b.restore(watchBackup);

      // The seed account: label and birthday attached, registry merged.
      expect(seedReport.secrets?.walletsMatched, 1);
      expect(seedReport.secrets?.derivationsAdded, 4);
      expect(seedReport.secrets?.derivationsRefused, isFalse);
      final seedWallet = valueOf(
        await b.phone.inventory.readWallet(
          seedBackup.group.bitcoinWalletIds.single,
        ),
      );
      expect(seedWallet.label, 'Main');
      expect(seedWallet.birthday, DateTime.utc(2026, 1, 2));
      expect(seedWallet.isDefault, isTrue);

      // The registry keeps its gap and its states, and allocation stays above.
      final registry = valueOf(await b.phone.inventory.listDerivations());
      expect(
        registry.map((child) => (child.index, child.status, child.alias)),
        [
          (0, 'active', 'child 0'),
          (1, 'active', 'child 1'),
          (2, 'revoked', 'child 2'),
          (9, 'active', 'after the gap'),
        ],
      );
      final next = valueOf(
        await b.phone.inventory.reserveHexDerivation(
          parent: Fingerprint(registry.first.parentFingerprint),
          length: 32,
        ),
      );
      expect(next.index, 10);

      // The watch-only account: matched by its public descriptors, not by id.
      expect(watchReport.secrets?.walletsMatched, 1);
      final watch = valueOf(
        await b.phone.inventory.readWallet(
          watchBackup.group.bitcoinWalletIds.single,
        ),
      );
      expect(watch.id, isNot(a.watchWalletId));
      expect(watch.label, 'Cold storage');
      expect(watch.birthday, DateTime.utc(2026, 3, 4));
      expect(watch.signer, WalletSigner.remote);
      expect(watch.isDefault, isFalse);
      expect(watchReport.secrets?.derivationsAdded, 0);

      // Labels and freezes.
      expect(b.labels.entries.keys, hasLength(3));
      expect(b.labels.frozen, {'$_txid:1'});
    },
  );

  test('applying a backup again changes nothing more', () async {
    final a = await sourcePhone();
    final b = await freshPhone(seed: a.seed, watch: a.watch);
    final backups = await discover(b);
    for (final backup in backups) {
      await b.restore(backup);
    }
    final before = valueOf(await b.phone.inventory.listDerivations());
    for (final backup in backups) {
      final again = await b.restore(backup);
      expect(again.secrets?.derivationsAdded, 0);
      expect(again.secrets?.derivationsUpdated, 0);
      expect(again.secrets?.walletLabelsApplied, 0);
      expect(again.secrets?.walletBirthdaysApplied, 0);
    }
    expect(
      valueOf(await b.phone.inventory.listDerivations()).length,
      before.length,
    );
    expect(b.labels.entries.keys, hasLength(3));
  });

  test(
    'an interruption between Secrets and Labels resumes without duplicates',
    () async {
      final a = await sourcePhone();
      final b = await freshPhone(seed: a.seed, watch: a.watch);
      final seedBackup = (await discover(b))
          .singleWhere((backup) => !backup.group.isWatchOnly);

      b.labels.failApply = true;
      final first = await b.restore(seedBackup, expectPartial: true);
      expect(first.secrets?.derivationsAdded, 4);
      expect(first.labels, isNull);
      expect(b.labels.entries, isEmpty);

      b.labels.failApply = false;
      final second = await b.restore(seedBackup);
      expect(second.secrets?.derivationsAdded, 0, reason: 'no duplicate rows');
      expect(second.labels?.labelsApplied, 2);
      expect(valueOf(await b.phone.inventory.listDerivations()), hasLength(4));
    },
  );

  test(
    'an older archive never lowers allocation on a phone that moved on',
    () async {
      final a = await sourcePhone();
      final b = await freshPhone(seed: a.seed, watch: a.watch);
      final parent = valueOf(await b.phone.inventory.listWallets())
          .firstWhere((wallet) => wallet.secretFingerprint != null)
          .secretFingerprint!;
      // This phone already allocated far beyond the archive.
      valueOf(
        await b.phone.inventory.mergeDerivationArchive(
          parent: Fingerprint(parent),
          records: [
            RecordedDerivation(
              path: "128169'/32'/12'",
              parentFingerprint: parent,
              application: 'hex',
              status: 'active',
              alias: 'newer',
            ),
          ],
        ),
      );
      final seedBackup = (await discover(b))
          .singleWhere((backup) => !backup.group.isWatchOnly);
      await b.restore(seedBackup);
      final next = valueOf(
        await b.phone.inventory.reserveHexDerivation(
          parent: Fingerprint(parent),
          length: 32,
        ),
      );
      expect(next.index, 13);
    },
  );

  test(
    'the same public key in two wallets is neither offered nor applied',
    () async {
      final a = await sourcePhone();
      final b = await freshPhone(
        seed: a.seed,
        // A watch-only copy of the seed account's own public key.
        watch: a.seed,
      );
      expect(await discover(b), isEmpty);

      final groups = await b.groups();
      expect(groups.every((group) => group.ambiguous), isTrue);
      final forced = DiscoveredBackup(
        group: groups.first,
        destination: storage.destination,
        storedAt: null,
        content: BackupContent(
          labels: LabelsSnapshot(
            records: const [],
            unattributedCount: 0,
            skippedCount: 0,
          ),
          wallets: const [],
          derivations: const [],
        ),
        scope: 'all',
      );
      final plan = MergePlan(
        groupId: forced.group.id,
        baseDigest: 'x',
        additions: [],
        unchanged: 0,
        conflicts: [],
        freezes: [],
      );
      expect(
        await ApplyRestoreUsecase(
          b.labels,
          b.secretsPort,
        ).execute(forced, plan, MergeChoices({})),
        isA<Err<RestoreReport, BackupMetadataFailure>>(),
      );
      expect(valueOf(await b.phone.inventory.listDerivations()), isEmpty);
    },
  );

  test('the files hold no word, key or readable descriptor', () async {
    final a = await sourcePhone();
    for (final bytes in storage.objects.values) {
      final text = latin1.decode(bytes);
      for (final word in [
        'abandon',
        'legal',
        'winner',
        'tpub',
        'tprv',
        'xprv',
      ]) {
        expect(text, isNot(contains(word)));
      }
      expect(text, isNot(contains(a.seed.external)));
      final items = await bip138Decrypt(
        bytes: bytes,
        candidatePublicDescriptors: [a.seed.external, a.watch.external],
      );
      expect(items, isNotNull);
      final plaintext = items!.map((item) => utf8.decode(item.bytes)).join();
      for (final word in ['abandon', 'legal', 'winner', 'prv', 'mnemonic']) {
        expect(plaintext, isNot(contains(word)));
      }
    }
  });
}
