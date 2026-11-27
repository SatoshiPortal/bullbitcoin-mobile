import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/custody.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';
import 'package:settings/src/wallet_details/domain/delete_wallet_usecase.dart';
import 'package:settings/src/wallet_details/domain/wallet_details_failure.dart';
import 'package:swaps/order_swaps.dart';
import 'package:swaps/swaps.dart';
import 'package:sync/sync.dart' show SyncStorageFailure;

import '../support/fakes.dart';
import '../support/inventory.dart';

class _MockOrderSwaps extends Mock implements OrderSwaps {}

/// The backup proofs the deletion stage judges, per test. A seed is missing
/// unless this test states it is verified.
final class _Proofs implements InventoryBackupVerification {
  final Set<Fingerprint> verified = {};
  bool unreadable = false;

  @override
  Future<Result<BackupProof, SecretFailure>> verify(
    Fingerprint secret, {
    ({String walletId, bool regtest})? replacingWallet,
  }) async => unreadable
      ? const Err(BackupStateUnavailableFailure())
      : Ok(
          verified.contains(secret)
              ? BackupProof.verified
              : BackupProof.missing,
        );
}

/// Fail-closed wallet deletion, against the real inventory and the real
/// [Secrets] keystore.
///
/// The inventory owns the registrations and the custody references, so the
/// checks that matter — a remaining local wallet keeps its seed, a watch-only
/// origin does not, an unprovable read refuses — are asserted on the stores the
/// product uses rather than on mocks that would agree with the usecase.
///
/// Stage order, as asserted below: pending Exchange orders, inventory read,
/// default refusal, ongoing swaps, native deletion, inventory removal, catalog
/// confirmation, then orphan-seed cleanup. Any failure before the last stage
/// leaves the seed alone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const words = [
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'about',
  ];

  late Directory logDirectory;
  late FakeSecureStoragePlatform storage;
  late Secrets secrets;
  late String fingerprint;
  late String walletId;
  late String seedKey;
  late InventoryFixture inventory;
  late FakeNativeLifecycle native;
  late FakeSwapStore swaps;
  late _MockOrderSwaps orders;
  late _Proofs proofs;
  late SeedReferences references;
  late DeleteWalletUsecase usecase;

  Iterable<String> storedSeeds() =>
      storage.entries.keys.where((key) => key.startsWith('seed_'));

  Future<List<String>> deletionLog() async {
    final messages = <String>[];
    for (final row in await log.readLogs()) {
      final columns = row.split('\t');
      if (columns.length < 3) continue;
      final message = columns[2];
      if (message.startsWith('Wallet delete') ||
          message.startsWith('Wallet deleted') ||
          message.startsWith('Seed ')) {
        messages.add(message);
      }
    }
    return messages;
  }

  Future<void> registerLocal(
    String id, {
    bool isDefault = false,
    String? secret,
  }) => inventory.register(
    walletRow(
      id: id,
      masterFingerprint: secret ?? fingerprint,
      secretFingerprint: secret ?? fingerprint,
      signer: 'local',
      isDefault: isDefault,
    ),
  );

  Future<RegisteredWallet?> findWallet(String id) async =>
      switch (await inventory.inventory.findWallet(id)) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError(
          'Wallet lookup failed: ${failure.runtimeType}',
        ),
      };

  setUp(() async {
    logDirectory = await Directory.systemTemp.createTemp('wallet-delete-log-');
    log = Logger.replace(directory: logDirectory);
    storage = FakeSecureStoragePlatform()..install();
    secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => logDirectory.path,
    );
    final stored = await secrets.import(
      words: words,
      language: Language.english,
    );
    fingerprint = switch (stored) {
      Ok(:final value) => value.id.hex,
      Err(:final failure) => throw StateError(
        'Seed import failed: ${failure.runtimeType}',
      ),
    };
    walletId = walletIdFor(fingerprint);
    seedKey = 'seed_$fingerprint';

    inventory = await InventoryFixture.open();
    native = FakeNativeLifecycle();
    swaps = FakeSwapStore();
    orders = _MockOrderSwaps();
    when(
      () => orders.getPendingOrders(),
    ).thenAnswer((_) async => const Ok<List<OrderSwapRecord>, SwapFailure>([]));
    references = SeedReferences.forInventory(
      inventory.inventory,
      admission: SqliteParentCustodyAdmission(
        directory: () async => inventory.directory.path,
        mayCreate: true,
      ),
      backupVerification: proofs = _Proofs()
        ..verified.add(Fingerprint(fingerprint)),
    );
    usecase = DeleteWalletUsecase(
      inventory: inventory.inventory,
      native: native,
      swaps: swaps,
      orders: orders,
      references: references,
      secrets: secrets,
    );
  });

  tearDown(() async {
    await inventory.close();
    await log.flush();
    await logDirectory.delete(recursive: true);
  });

  group('deletes a wallet', () {
    test('and trashes the seed no remaining wallet references', () async {
      await registerLocal(walletId);

      final result = await usecase.execute(walletId);

      expect(result, isA<Ok<void, WalletDetailsFailure>>());
      expect(await findWallet(walletId), isNull);
      expect(native.deleted.single.id, walletId);
      expect(native.deleted.single.network, BitcoinNetwork.mainnet);
      expect(native.catalogDeletedKeys.single, native.deleted.single);
      expect(storedSeeds(), isEmpty);
      expect(await deletionLog(), [
        'Wallet deleted outcome=ok',
        'Seed deleted source=wallet_cleanup',
      ]);
    });

    test('and keeps the seed a second local wallet still uses', () async {
      await registerLocal(walletId);
      await registerLocal(walletIdFor(fingerprint, purpose: 49));

      final result = await usecase.execute(walletId);

      expect(result, isA<Ok<void, WalletDetailsFailure>>());
      expect(storedSeeds(), [seedKey]);
      expect(await deletionLog(), [
        'Wallet deleted outcome=ok',
        'Seed cleanup skipped reason=referenced',
      ]);
    });

    test(
      'and keeps the seed for a custody reference in another case',
      () async {
        // The deleted row spells its reference in uppercase — a legacy row —
        // and the surviving local wallet in lowercase. The custody query
        // normalizes both, so the survivor still protects the seed.
        await registerLocal(walletId, secret: fingerprint.toUpperCase());
        await registerLocal(walletIdFor(fingerprint, purpose: 44));

        final result = await usecase.execute(walletId);

        expect(result, isA<Ok<void, WalletDetailsFailure>>());
        expect(storedSeeds(), [seedKey]);
        expect(await deletionLog(), [
          'Wallet deleted outcome=ok',
          'Seed cleanup skipped reason=referenced',
        ]);
      },
    );

    test(
      'and trashes the seed a watch-only origin alone still names',
      () async {
        // The #2634 class: a Coldcard watch-only imported from the same seed
        // shows its origin but never held it. Counting it as a user left the
        // seed orphaned, and the very words on paper became unimportable.
        await registerLocal(walletId);
        await inventory.register(
          walletRow(
            id: walletIdFor(fingerprint, purpose: 44),
            masterFingerprint: fingerprint.toUpperCase(),
            purpose: 44,
          ),
        );

        final result = await usecase.execute(walletId);

        expect(result, isA<Ok<void, WalletDetailsFailure>>());
        expect(storedSeeds(), isEmpty);
        expect(await deletionLog(), [
          'Wallet deleted outcome=ok',
          'Seed deleted source=wallet_cleanup',
        ]);
      },
    );

    test('and never looks a seed up for a watch-only wallet', () async {
      const id = "wpkh([A1B2C3D4/84h/0h/0h])";
      await inventory.register(
        walletRow(id: id, masterFingerprint: 'A1B2C3D4'),
      );

      await expectLater(usecase.execute(id), completes);

      expect(native.deleted.single.id, id);
      expect(storedSeeds(), [seedKey]);
      expect(await deletionLog(), ['Wallet deleted outcome=ok']);
    });

    test('and completes when the seed cleanup itself fails', () async {
      await registerLocal(walletId);
      // The cleanup is best effort: a keystore that refuses the delete leaves
      // an orphan entry, never a wallet the user could not remove.
      storage.scriptedWrites.add(Exception('keystore refused the delete'));

      await expectLater(usecase.execute(walletId), completes);

      expect(await findWallet(walletId), isNull);
      expect(storedSeeds(), [seedKey]);
    });

    test('and keeps the seed that has no tested backup', () async {
      await registerLocal(walletId);
      proofs.verified.clear();

      final result = await usecase.execute(walletId);

      // The wallet deletion the user asked for still succeeds; the seed stays,
      // because without a tested backup those words exist nowhere else.
      expect(result, isA<Ok<void, WalletDetailsFailure>>());
      expect(await findWallet(walletId), isNull);
      expect(storedSeeds(), [seedKey]);
      expect(await deletionLog(), [
        'Wallet deleted outcome=ok',
        'Seed cleanup refused reason=backup_required',
      ]);
    });

    test('and keeps the seed when the backup state cannot be read', () async {
      await registerLocal(walletId);
      proofs.unreadable = true;

      final result = await usecase.execute(walletId);

      expect(result, isA<Ok<void, WalletDetailsFailure>>());
      expect(await findWallet(walletId), isNull);
      expect(storedSeeds(), [seedKey]);
      expect(await deletionLog(), [
        'Wallet deleted outcome=ok',
        'Seed cleanup refused reason=backup_unavailable',
      ]);
    });
  });

  group('keeps the seed and refuses unsafe deletions', () {
    test('for a pending Exchange order sending from the wallet', () async {
      await registerLocal(walletId);
      when(() => orders.getPendingOrders())
          .thenAnswer((_) async => Ok([_order(sourceWalletId: walletId)]));

      final result = await usecase.execute(walletId);

      expect(_failureOf(result), isA<WalletDetailsOngoingSwapsFailure>());
      expect(await findWallet(walletId), isNotNull);
      expect(native.deleted, isEmpty);
      expect(storedSeeds(), [seedKey]);
    });

    test('for a pending Exchange order paying into the wallet', () async {
      await registerLocal(walletId);
      when(() => orders.getPendingOrders())
          .thenAnswer((_) async => Ok([_order(destinationWalletId: walletId)]));

      final result = await usecase.execute(walletId);

      expect(_failureOf(result), isA<WalletDetailsOngoingSwapsFailure>());
      expect(native.deleted, isEmpty);
    });

    test('when the pending orders cannot be read', () async {
      await registerLocal(walletId);
      when(() => orders.getPendingOrders()).thenAnswer(
        (_) async => const Err(SwapStorageFailure('database unavailable')),
      );

      final result = await usecase.execute(walletId);

      final failure = _failureOf(result);
      expect(failure, isA<WalletDetailsUnavailableFailure>());
      // The swap feature's reason stays in the log; the wallet family carries
      // only its own wording.
      expect(failure.logMessage, contains('pending order check'));
      expect(failure.logMessage, isNot(contains('database unavailable')));
      expect(native.deleted, isEmpty);
      expect(storedSeeds(), [seedKey]);
    });

    test('for a default wallet, before the swap and native stages', () async {
      await registerLocal(walletId, isDefault: true);

      final result = await usecase.execute(walletId);

      expect(_failureOf(result), isA<WalletDetailsDefaultFailure>());
      expect(swaps.ongoingQueries, isEmpty);
      expect(native.deleted, isEmpty);
      expect(await findWallet(walletId), isNotNull);
      expect(storedSeeds(), [seedKey]);
    });

    test('when the wallet is not registered', () async {
      final result = await usecase.execute(walletId);

      expect(_failureOf(result), isA<WalletDetailsNotFoundFailure>());
      expect(swaps.ongoingQueries, isEmpty);
      expect(native.deleted, isEmpty);
      expect(storedSeeds(), [seedKey]);
    });

    test('when the inventory cannot be read', () async {
      await registerLocal(walletId);
      inventory.inventory.lock();

      final result = await usecase.execute(walletId);

      expect(_failureOf(result), isA<WalletDetailsUnavailableFailure>());
      expect(native.deleted, isEmpty);
      expect(storedSeeds(), [seedKey]);
    });

    test('for an ongoing swap on the wallet', () async {
      await registerLocal(walletId);
      swaps.ongoingOutcome = Ok([_swap()]);

      final result = await usecase.execute(walletId);

      expect(_failureOf(result), isA<WalletDetailsOngoingSwapsFailure>());
      expect(swaps.ongoingQueries, [walletId]);
      expect(native.deleted, isEmpty);
      expect(await findWallet(walletId), isNotNull);
      expect(storedSeeds(), [seedKey]);
    });

    test('when the swap store cannot be read', () async {
      await registerLocal(walletId);
      swaps.ongoingOutcome = const Err(SwapsStorageFailure('db locked'));

      final result = await usecase.execute(walletId);

      final failure = _failureOf(result);
      expect(failure, isA<WalletDetailsUnavailableFailure>());
      expect(failure.logMessage, contains('ongoing swap check'));
      expect(native.deleted, isEmpty);
      expect(storedSeeds(), [seedKey]);
    });

    test('when the native deletion fails', () async {
      await registerLocal(walletId);
      native.deleteOutcome = (_) => const Err(SyncStorageFailure());

      final result = await usecase.execute(walletId);

      final failure = _failureOf(result);
      expect(failure, isA<WalletDetailsUnavailableFailure>());
      expect(failure.logMessage, contains('native: storage'));
      expect(native.deleted, hasLength(1));
      expect(native.catalogDeletedKeys, isEmpty);
      // The registration is untouched, so the wallet is still usable.
      expect(await findWallet(walletId), isNotNull);
      expect(storedSeeds(), [seedKey]);
    });

    test('when the inventory removal fails', () async {
      await registerLocal(walletId);
      // The inventory locks while the native deletion runs, so the
      // registration removal that follows it fails: nothing after it runs.
      native.beforeDelete = inventory.inventory.lock;

      final result = await usecase.execute(walletId);

      final failure = _failureOf(result);
      expect(failure, isA<WalletDetailsUnavailableFailure>());
      expect(failure.logMessage, 'inventory');
      expect(native.catalogDeletedKeys, isEmpty);
      expect(storedSeeds(), [seedKey]);
    });

    test('when the catalog confirmation fails, before seed cleanup', () async {
      await registerLocal(walletId);
      native.catalogDeletedOutcome = (_) => const Err(SyncStorageFailure());

      final result = await usecase.execute(walletId);

      final failure = _failureOf(result);
      expect(failure, isA<WalletDetailsUnavailableFailure>());
      expect(failure.logMessage, contains('catalog: storage'));
      expect(await findWallet(walletId), isNull);
      // The registration is gone but the deletion was never confirmed: the
      // seed must survive because the outcome is not proven.
      expect(storedSeeds(), [seedKey]);
      expect(await deletionLog(), isEmpty);
    });

    test('when another custody owner still references the seed', () async {
      await registerLocal(walletId);
      final owner = FakeSeedOwner(() async => Ok({Fingerprint(fingerprint)}));
      references.register(owner);

      final result = await usecase.execute(walletId);

      expect(result, isA<Ok<void, WalletDetailsFailure>>());
      expect(owner.reads, 1);
      expect(storedSeeds(), [seedKey]);
      expect(await deletionLog(), [
        'Wallet deleted outcome=ok',
        'Seed cleanup skipped reason=referenced',
      ]);
    });

    test('when another custody owner cannot prove its references', () async {
      await registerLocal(walletId);
      final owner = FakeSeedOwner(
        () async => const Err(SeedReferencesUnavailable()),
      );
      references.register(owner);

      final result = await usecase.execute(walletId);

      expect(result, isA<Ok<void, WalletDetailsFailure>>());
      expect(storedSeeds(), [seedKey]);
      expect(await deletionLog(), [
        'Wallet deleted outcome=ok',
        'Seed cleanup failed reason=references_unavailable',
      ]);
    });

    test('when another custody owner throws', () async {
      await registerLocal(walletId);
      final owner = FakeSeedOwner(() async => throw Exception('unavailable'));
      references.register(owner);

      final result = await usecase.execute(walletId);

      expect(result, isA<Ok<void, WalletDetailsFailure>>());
      expect(storedSeeds(), [seedKey]);
      expect(await deletionLog(), [
        'Wallet deleted outcome=ok',
        'Seed cleanup failed reason=references_unavailable',
      ]);
    });

    test(
      'when a local row outside the readable ids still names the seed',
      () async {
        // Re-added coverage: a local wallet whose id/origin is not decodable —
        // a legacy row the registration reader refuses — still holds the seed,
        // and the custody query must not trust decoded identities to notice.
        await registerLocal(walletId);
        await inventory.register(
          walletRow(
            id: 'invalid origin',
            masterFingerprint: fingerprint,
            secretFingerprint: fingerprint,
            signer: 'local',
          ),
        );

        final result = await usecase.execute(walletId);

        expect(result, isA<Ok<void, WalletDetailsFailure>>());
        expect(storedSeeds(), [seedKey]);
        expect(await findWallet('invalid origin'), isNotNull);
        expect(
          await inventory.inventory.readWallet('invalid origin'),
          isA<Err<WalletRegistration, SecretFailure>>().having(
            (read) => read.failure,
            'failure',
            isA<UnreadableWalletFailure>(),
          ),
        );
      },
    );

    test('when a local row carries an unusable custody reference', () async {
      await registerLocal(walletId);
      await inventory.register(
        walletRow(
          id: 'invalid origin',
          masterFingerprint: 'NOT-A-FP',
          secretFingerprint: 'NOT-A-FP',
          signer: 'local',
        ),
      );

      final result = await usecase.execute(walletId);

      expect(result, isA<Ok<void, WalletDetailsFailure>>());
      expect(storedSeeds(), [seedKey]);
      expect(await deletionLog(), [
        'Wallet deleted outcome=ok',
        'Seed cleanup failed reason=references_unavailable',
      ]);
    });
  });
}

WalletDetailsFailure _failureOf(Result<void, WalletDetailsFailure> result) =>
    switch (result) {
      Err(:final failure) => failure,
      Ok() => fail('expected a refusal'),
    };

OrderSwapRecord _order({String? sourceWalletId, String? destinationWalletId}) =>
    OrderSwapRecord(
      localId: 'local-1',
      purpose: OrderSwapPurpose.sendLightning,
      environment: OrderSwapEnvironment.testnet,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.lightning,
      isInAmountFixed: false,
      requestedAmountSat: BigInt.from(1000),
      sourceWalletId: sourceWalletId,
      destinationWalletId: destinationWalletId,
      destination: 'invoice',
      fallback: 'fallback',
      createdAt: DateTime.utc(2026),
      localStatus: OrderSwapLocalStatus.creationUnknown,
    );

Swap _swap() => Swap.lnReceive(
  id: 'swap-1',
  keyIndex: 0,
  type: SwapType.lightningToLiquid,
  status: SwapStatus.pending,
  environment: Environment.testnet,
  creationTime: DateTime.utc(2026),
  receiveWalletId: 'wallet-1',
  invoice: 'lnbc1',
);
