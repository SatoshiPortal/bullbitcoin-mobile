import '../../../support/wallet_registrations.dart';

import 'package:bb_mobile/features/wallet/data/sync_wallet_values_datasource.dart';

import 'dart:async';
import 'dart:io';

import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_service.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:sync/write.dart'
    show WalletNativeRuntime, WalletNativeLifecycle;
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' show Database;
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result, ScriptType;
import 'package:sync/sync.dart'
    show
        Balances,
        InputReservation,
        InputReservationPort,
        ReservedAddressPort,
        SyncFailure,
        SyncReason,
        SyncNotFoundFailure,
        SyncStorageFailure,
        WalletSnapshotException,
        WalletConnectionPort,
        WalletKey;
import 'package:sync/write.dart' show ElectrumSync;
import 'package:bb_mobile/features/wallet/data/wallet_sync_binding.dart';

import 'package:secrets/testing.dart';
import 'package:sync/testing.dart' show MemoryFreezeStore;

class _Native extends Mock implements WalletNativeLifecycle {}

class _Reporter extends Mock implements LoggerReporter {}

class _Values extends Mock implements SyncWalletValuesDatasource {}

class _Connections extends Mock implements WalletConnectionPort {}

class _Reserved extends Mock implements ReservedAddressPort {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SqliteDatabase database;
  late WalletRegistrations metadata;
  late _Native native;
  late WalletRepository repository;
  late Secret secret;
  late WalletMetadataModel row;
  late WatchOnlyDescriptorEntity descriptor;
  late FakeSecureStoragePlatform storage;
  late _Reporter reporter;

  setUp(() async {
    storage = FakeSecureStoragePlatform()..install();
    // Published BIP84 vector; the secret stays in the in-memory test keystore.
    final imported = await Secrets(scratchDirectory: () async => '/tmp').import(
      words: 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'
          .split(' '),
      language: Language.english,
    );
    secret = (imported as Ok<Secret, SecretFailure>).value;
    row = await WalletMetadataService.deriveFromSecret(
      secret: secret,
      network: Network.bitcoinMainnet,
      scriptType: ScriptType.bip84,
      isDefault: false,
    );
    registerFallbackValue(row);
    registerFallbackValue(WalletSyncBinding.keyFromMetadata(row));
    descriptor = await WatchOnlyWalletEntity.parse(
      row.externalPublicDescriptor,
    ) as WatchOnlyDescriptorEntity;
    directory = await Directory.systemTemp.createTemp('wallet-create-');
    reporter = _Reporter();
    await initializeLogging(directory: directory, reporter: reporter);
    database = SqliteDatabase(
      NativeDatabase(File('${directory.path}/app.sqlite'), setup: _configure),
    );
    metadata = MemoryWalletRegistrations();
    native = _Native();
    when(() => native.prepareCreate(any()))
        .thenAnswer((_) async => const Ok(null));
    final values = _Values();
    when(() => values.getBalance(key: any(named: 'key'))).thenAnswer(
      (_) async => Balances(
        confirmedSat: BigInt.zero,
        immatureSat: BigInt.zero,
        trustedPendingSat: BigInt.zero,
        untrustedPendingSat: BigInt.zero,
        spendableSat: BigInt.zero,
        totalSat: BigInt.zero,
      ),
    );
    repository = WalletRepository(
      native: native,
      walletRegistrations: metadata,
      wallet: (_) async => throw StateError('no native access expected'),
      walletValuesDatasource: values,
      synchronize: (
        _, {
        discover = false,
        allowInitialScan = true,
        reason = SyncReason.auto,
      }) async {},
      syncStarted: const Stream.empty(),
      syncFinished: const Stream.empty(),
    );
    addTearDown(() async {
      await database.close();
      await log.flush();
      await directory.delete(recursive: true);
    });
  });

  Future<Wallet> create(String path) => switch (path) {
    'secret' => repository.createWallet(
      secret: secret,
      network: Network.bitcoinMainnet,
      scriptType: ScriptType.bip84,
    ),
    'descriptor' => repository.importDescriptor(
      watchOnlyDescriptor: descriptor,
    ),
    _ => repository.importWatchOnlyXpub(
      xpub: row.xpub,
      network: Network.bitcoinMainnet,
      scriptType: ScriptType.bip84,
      label: 'import',
    ),
  };

  Future<SqliteDatabase> independent() async {
    await metadata.fetchAll();
    final observer = SqliteDatabase(
      NativeDatabase(File('${directory.path}/app.sqlite'), setup: _configure),
    );
    await observer.customSelect('SELECT 1').get();
    return observer;
  }

  test(
    'regression: an independent settings write succeeds during native create',
    () async {
      final observer = await independent();
      final entered = Completer<void>();
      final release = Completer<void>();
      when(() => native.create(any())).thenAnswer((_) async {
        entered.complete();
        await release.future;
        return const Ok(null);
      });
      final creating = create('secret');
      await entered.future;
      try {
        await observer.customStatement('UPDATE settings SET rowid = rowid');
      } finally {
        release.complete();
        await creating;
        await observer.close();
      }
    },
  );

  test('regression: unrelated settings commit during prepare does not abort import', () async {
    final observer = await independent();
    when(() => native.prepareCreate(any())).thenAnswer((_) async {
      await observer.customStatement('UPDATE settings SET rowid = rowid');
      return const Ok(null);
    });
    when(() => native.create(any())).thenAnswer((_) async => const Ok(null));
    try {
      await create('secret');
      verify(() => native.create(any())).called(1);
    } finally {
      await observer.close();
    }
  });

  for (final path in ['secret', 'descriptor', 'xpub']) {
    test('$path rolls back failed native creation and permits retry', () async {
      final secretsBefore = Map.of(storage.entries);
      when(() => native.create(any())).thenAnswer((call) async {
        final pending = call.positionalArguments.single as WalletKey;
        expect(
          await metadata.fetch(pending.id),
          isNotNull,
          reason: 'the writer must resolve the provisional catalog row',
        );
        return const Err(SyncStorageFailure());
      });
      await expectLater(
        create(path),
        throwsA(
          isA<WalletSnapshotException>().having(
            (error) => error.failure,
            'failure',
            isA<SyncStorageFailure>(),
          ),
        ),
      );
      expect(await metadata.fetchAll(), isEmpty);
      expect(
        (await log.readLogs())
            .where((line) => line.split('\t')[1] == 'WARNING')
            .map((line) => line.split('\t')[2]),
        ['Wallet creation failed catalog row removed'],
      );
      verifyZeroInteractions(reporter);
      expect(storage.entries, secretsBefore);
      when(() => native.create(any())).thenAnswer((_) async => const Ok(null));
      final wallet = await create(path);
      expect((await metadata.fetchAll()).single.id, wallet.id);
      expect(storage.entries, secretsBefore);
      verifyNever(() => native.delete(any()));
    });
  }

  test('real writer resolves metadata during native creation', () async {
    final runtime = WalletNativeRuntime.open(
      catalog: TestWalletCatalog(metadata),
      reserved: _Reserved(),
      inputReservations: _NoInputReservations(),
      deleteCatalogEntry: (key) async {
        await metadata.delete(key.id);
        return const Ok(null);
      },
      sync: ElectrumSync(
        connections: _Connections(),
        documentsDirectory: () async => directory.path,
        readRevision: (_) async => const Err(SyncNotFoundFailure()),
      ),
      documentsDirectory: () async => directory.path,
      freezes: MemoryFreezeStore(),
      connections: _Connections(),
    );
    when(() => native.create(any())).thenAnswer(
      (call) => runtime.create(call.positionalArguments.single as WalletKey),
    );
    try {
      final wallet = await create('secret');
      expect((await metadata.fetchAll()).single.id, wallet.id);
    } finally {
      await runtime.close();
    }
  });

  test('existing metadata survives a rejected creation', () async {
    final existing = row.copyWith(label: 'original');
    await metadata.insert(existing);
    when(() => native.create(any()))
        .thenThrow(const FileSystemException('injected'));
    await expectLater(
      create('secret'),
      throwsA(isA<WalletAlreadyExistsException>()),
    );
    expect(await metadata.fetch(row.id), existing);
    verifyNever(() => native.create(any()));
  });

  test('insert conflict never compensates the winning catalog row', () async {
    final prepared = Completer<void>();
    final resume = Completer<void>();
    when(() => native.prepareCreate(any())).thenAnswer((_) async {
      prepared.complete();
      await resume.future;
      return const Ok(null);
    });
    final rejected = expectLater(
      create('secret'),
      throwsA(isA<WalletAlreadyExistsException>()),
    );
    await prepared.future;
    final winner = row.copyWith(label: 'concurrent winner');
    await metadata.insert(winner);
    resume.complete();
    await rejected;
    expect(await metadata.fetch(row.id), winner);
    verifyNever(() => native.create(any()));
    verifyNever(() => native.delete(any()));
  });

  test('concurrent duplicate cannot replace a successful creation', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    var attempts = 0;
    when(() => native.create(any())).thenAnswer((_) async {
      if (++attempts > 1) {
        throw const FileSystemException('duplicate native create');
      }
      entered.complete();
      await release.future;
      return const Ok(null);
    });
    final first = create('xpub');
    await entered.future;
    final second = expectLater(
      create('xpub'),
      throwsA(isA<WalletAlreadyExistsException>()),
    );
    release.complete();
    final wallet = await first;
    await second;
    expect((await metadata.fetchAll()).single.id, wallet.id);
    expect(attempts, 1);
  });
}

void _configure(Database db) {
  db.execute('PRAGMA busy_timeout = 2000');
  db.execute('PRAGMA journal_mode = WAL');
  db.execute('PRAGMA synchronous = FULL');
}

final class _NoInputReservations implements InputReservationPort {
  @override
  Future<Result<List<InputReservation>, SyncFailure>> reservations() async =>
      const Ok([]);
}
