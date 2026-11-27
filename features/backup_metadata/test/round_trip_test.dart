import 'dart:convert';
import 'dart:io';

import 'package:backup_metadata/backup_metadata.dart';
import 'package:backup_metadata/setup.dart'
    show BackupInventoryPort, MetadataBackupLabels;
import 'package:backup_metadata/src/domain/usecases/apply_restore_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labels/backup.dart';
import 'package:primitives/primitives.dart';
import 'package:rust_bindings/rust_bindings.dart';
import 'package:secrets/metadata_backup.dart';
import 'package:secrets/storage.dart' show SecretsInventory;
import 'package:secrets/secrets.dart' show Language, WalletSigner;

import 'package:labels/testing.dart';

import 'support/flow_harness.dart';
import 'support/round_trip_support.dart';
import 'support/memory_backup_storage.dart';
import 'support/open_inventory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await BullSdk.init();
    await loadTestFonts();
  });

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
      Engine engine,
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
        words: seedWords.split(' '),
        language: Language.english,
      ),
    );
    final seed = await descriptorsOf(a, seedWords);
    final watch = await descriptorsOf(a, watchWords);
    final seedId = 'wpkh([${secret.id.hex}/84h/1h/0h])';
    const watchId = 'wpkh([0a1b2c3d/84h/1h/0h])';
    valueOf(
      await a.inventory.registerWallet(
        registeredWallet(
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
        registeredWallet(
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
        session: valueOf(await a.inventory.backupSession()),
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

    final engine = Engine(a, storage);
    engine.labels
      ..add(
        BackupLabelRecord(
          chain: BackupLabelChain.bitcoin,
          type: BackupLabelType.tx,
          ref: txid,
          label: 'rent',
          walletId: seedId,
        ),
        seedId,
      )
      ..add(
        BackupLabelRecord(
          chain: BackupLabelChain.bitcoin,
          type: BackupLabelType.output,
          ref: '$txid:1',
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
  Future<Engine> freshPhone({
    required ({String external, String internal}) seed,
    required ({String external, String internal}) watch,
    String watchId = 'wpkh([99999999/84h/1h/0h])',
    LabelBackupsFixture? real,
  }) async {
    final b = await phone('b');
    final secret = valueOf(
      await b.secrets.import(
        words: seedWords.split(' '),
        language: Language.english,
      ),
    );
    valueOf(
      await b.inventory.registerWallet(
        registeredWallet(
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
        registeredWallet(
          id: watchId,
          network: 'bitcoinTestnet',
          external: watch.external,
          internal: watch.internal,
          signer: 'remote',
        ),
      ),
    );
    return Engine(b, storage, real: real);
  }

  Future<List<DiscoveredBackup>> discover(Engine engine) async =>
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
      expect(seedBackup.scope.view, 'all');

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
      expect(b.labels.frozen, {'$txid:1'});
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
          session: valueOf(await b.phone.inventory.backupSession()),
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
        scope: valueOf(await b.secretsPort.session()),
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

  test('with the real Labels, a re-imported watch-only keeps its label and freeze under its new id', () async {
    // Phone A: a watch-only account with a label and a frozen coin.
    final a = await phone('a');
    final watch = await descriptorsOf(a, watchWords);
    const oldId = 'wpkh([0a1b2c3d/84h/1h/0h])';
    valueOf(
      await a.inventory.registerWallet(
        registeredWallet(
          id: oldId,
          network: 'bitcoinTestnet',
          external: watch.external,
          internal: watch.internal,
          signer: 'remote',
          label: 'Cold storage',
        ),
      ),
    );
    final fixtureA = LabelBackupsFixture.open();
    addTearDown(fixtureA.close);
    fixtureA.own(oldId, txid, 1);
    await fixtureA.freeze(oldId, txid, 1);
    await fixtureA.addTransactionLabel(
      walletId: oldId,
      txId: txid,
      label: 'cold rent',
    );
    final source = Engine(a, storage, real: fixtureA);
    await source.backUpEverything();
    expect(storage.created, 1);

    // Phone B: the same public account, re-imported under another id.
    final b = await phone('b');
    const newId = 'wpkh([99999999/84h/1h/0h])';
    valueOf(
      await b.inventory.registerWallet(
        registeredWallet(
          id: newId,
          network: 'bitcoinTestnet',
          external: watch.external,
          internal: watch.internal,
          signer: 'remote',
        ),
      ),
    );
    final fixtureB = LabelBackupsFixture.open();
    addTearDown(fixtureB.close);
    fixtureB.own(newId, txid, 1);
    final target = Engine(b, storage, real: fixtureB);
    await target.store.locked((_) async {}, view: 'all');

    final backup = (await discover(target)).single;
    expect(backup.content.wallets.single.walletId, newId);
    final report = await target.restore(backup);

    expect(report.labels?.freezes.values, [FreezeOutcome.applied]);
    expect(await fixtureB.frozen(), [(walletId: newId, txId: txid, vout: 1)]);
    final labels = await fixtureB.labels();
    expect(labels.single.label, 'cold rent');
    expect(labels.single.origin, newId, reason: 'attributed to the new id');
  });

  test('a key present in another view is never published nor restored', () async {
    final a = await sourcePhone();
    final b = await freshPhone(seed: a.seed, watch: a.watch);
    // The same public key of the seed account, held by a wallet of a second
    // view, its checksum spelled differently.
    await b.phone.inventory.insertWalletInViewForTesting(
      view: 'other',
      wallet: registeredWallet(
        id: 'wpkh([abcdef01/84h/1h/0h])',
        network: 'bitcoinTestnet',
        external: '${a.seed.external}#abcd1234',
        internal: '${a.seed.internal}#abcd1234',
        signer: 'remote',
      ),
    );

    final before = storage.created;
    final ids = {for (final group in await b.groups()) group.id};
    valueOf(
      await b.repository.configure(
        destination: storage.destination,
        groups: ids,
        deleteOwnedFiles: false,
      ),
    );
    final status = valueOf(await b.repository.run());
    final seedGroup = status.groups.singleWhere(
      (entry) => !entry.group.isWatchOnly,
    );
    expect(seedGroup.group.ambiguous, isTrue);
    expect(seedGroup.failure, isA<BackupMetadataIncompatibleFailure>());
    expect(storage.created, before, reason: 'nothing of it was published');
    // And a file another phone published for that key is attributed to no one.
    expect(
      (await discover(b)).where((backup) => !backup.group.isWatchOnly),
      isEmpty,
    );
  });

  test(
    'a label that is a recovery phrase is left out, counted and never written',
    () async {
      final a = await sourcePhone();
      const phrase =
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon about';
      final seedId = (await a.engine.groups())
          .firstWhere((g) => !g.isWatchOnly)
          .bitcoinWalletIds
          .single;
      a.engine.labels.add(
        BackupLabelRecord(
          chain: BackupLabelChain.bitcoin,
          type: BackupLabelType.tx,
          ref: 'dd' * 32,
          label: phrase,
          walletId: seedId,
        ),
        seedId,
      );
      final status = valueOf(await a.engine.repository.run());
      expect(status.excluded, 1);
      expect(status.groups.where((g) => g.excluded > 0), hasLength(1));
      for (final bytes in storage.objects.values) {
        final items = await bip138Decrypt(
          bytes: bytes,
          candidatePublicDescriptors: [a.seed.external, a.watch.external],
        );
        final plaintext = items!.map((item) => utf8.decode(item.bytes)).join();
        expect(plaintext, isNot(contains('abandon')));
        expect(plaintext, isNot(contains('dd' * 32)));
      }
    },
  );

  group(
    'Labels is withdrawn the session down to its transaction and each freeze',
    () {
      test(
        'between the inventory read and the transaction nothing is written',
        () async {
          final a = await sourcePhone();
          final fixture = LabelBackupsFixture.open();
          addTearDown(fixture.close);
          final b = await freshPhone(
            seed: a.seed,
            watch: a.watch,
            real: fixture,
          );
          final backup = (await discover(b))
              .singleWhere((item) => !item.group.isWatchOnly);
          fixture.own(backup.group.bitcoinWalletIds.single, txid, 1);
          final plan = valueOf(
            await b.labelsPort.preview(
              backup.scope,
              backup.group,
              backup.content.labels,
            ),
          );

          // The adapter re-reads the inventory; the lock lands right after.
          final adapter = MetadataBackupLabels(
            inventory: _LockAfterRead(b.inventoryPort, b.phone.inventory),
            backups: fixture.backups,
          );
          final session = valueOf(await b.secretsPort.session());
          final result = await adapter.apply(session, plan, MergeChoices({}));

          expect(
            result.fold((_) => null, (failure) => failure),
            isA<BackupMetadataScopeChangedFailure>(),
          );
          expect(await fixture.labels(), isEmpty);
          expect(await fixture.frozen(), isEmpty);
        },
      );

      test('between two freezes the second one is not applied', () async {
        final a = await sourcePhone();
        final seedId = (await a.engine.groups())
            .firstWhere((group) => !group.isWatchOnly)
            .bitcoinWalletIds
            .single;
        a.engine.labels.add(
          BackupLabelRecord(
            chain: BackupLabelChain.bitcoin,
            type: BackupLabelType.output,
            ref: '$txid:2',
            spendable: false,
            walletId: seedId,
          ),
          seedId,
        );
        valueOf(await a.engine.repository.run());

        final fixture = LabelBackupsFixture.open();
        addTearDown(fixture.close);
        final b = await freshPhone(seed: a.seed, watch: a.watch, real: fixture);
        // The newest copy first: the file was rewritten with the second freeze.
        final backup = (await discover(b))
            .firstWhere((item) => !item.group.isWatchOnly);
        final walletId = backup.group.bitcoinWalletIds.single;
        fixture
          ..own(walletId, txid, 1)
          ..own(walletId, txid, 2);
        final plan = valueOf(
          await b.labelsPort.preview(
            backup.scope,
            backup.group,
            backup.content.labels,
          ),
        );
        expect(plan.freezes, hasLength(2));

        // The lock lands after the first coin is frozen.
        var frozen = 0;
        fixture.onFreeze = () {
          if (++frozen == 1) b.phone.inventory.lock();
        };
        final result = await b.labelsPort.apply(
          backup.scope,
          plan,
          MergeChoices({}),
        );
        final report = valueOf(result);

        expect(report.freezes.values, [
          FreezeOutcome.applied,
          FreezeOutcome.failed,
        ]);
        expect(await fixture.frozen(), hasLength(1));
      });
    },
  );

  testWidgets(
    'after an interruption a new engine resumes from the UI without duplicates',
    (tester) async {
      late LabelBackupsFixture fixture;
      late Engine second;
      late DiscoveredBackup seedBackup;
      late String seedWalletId;

      // Real IO (native codec, SQLite, files) runs outside the fake clock.
      await tester.runAsync(() async {
        final a = await sourcePhone();
        fixture = LabelBackupsFixture.open();
        final first = await freshPhone(
          seed: a.seed,
          watch: a.watch,
          real: fixture,
        );
        seedBackup = (await discover(first))
            .singleWhere((backup) => !backup.group.isWatchOnly);
        seedWalletId = seedBackup.group.bitcoinWalletIds.single;
        fixture.own(seedWalletId, txid, 1);

        // Secrets commits its part, then the app dies before Labels is asked.
        final committed = valueOf(
          await first.secretsPort.restore(
            seedBackup.scope,
            seedBackup.group,
            seedBackup.content,
          ),
        );
        expect(committed.derivationsAdded, 4);
        expect(await fixture.frozen(), isEmpty);
        expect(await fixture.labels(), isEmpty);

        // A new engine over the same phone, journal and destination.
        second = Engine(first.phone, storage, real: fixture);
      });
      addTearDown(fixture.close);

      /// Lets real IO finish, frame by frame, until [finder] shows up.
      Future<void> settleUntil(Finder finder) async {
        for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 250)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(finder, findsWidgets);
      }

      await pumpFlowOver(tester, second);
      await settleUntil(find.text('Restore from backup'));
      await tester.tap(find.text('Restore from backup'));
      await settleUntil(find.text(seedBackup.group.displayName));
      await tester.tap(find.text(seedBackup.group.displayName));
      await settleUntil(find.text('Restore'));
      await tester.tap(find.text('Restore').last);
      await settleUntil(find.text('Labels restored'));

      expect(find.text('Labels restored'), findsOneWidget);
      await tester.runAsync(() async {
        // Nothing twice: Secrets did not add its children again, Labels wrote
        // once.
        expect(
          valueOf(await second.phone.inventory.listDerivations()),
          hasLength(4),
        );
        expect(await fixture.frozen(), [
          (walletId: seedWalletId, txId: txid, vout: 1),
        ]);
        expect(
          (await fixture.labels()).where((l) => l.reference == txid),
          hasLength(1),
        );
      });
    },
  );
}

/// An inventory port whose read is followed by a lock, as if the user locked
/// the app while the adapter was looking at it.
final class _LockAfterRead implements BackupInventoryPort {
  final BackupInventoryPort inner;
  final SecretsInventory inventory;

  _LockAfterRead(this.inner, this.inventory);

  @override
  Future<Result<BackupInventory, BackupMetadataFailure>> read() async {
    final result = await inner.read();
    inventory.lock();
    return result;
  }
}
