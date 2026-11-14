import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/wallet/data/bdk_wallet_datasource.dart';
import 'package:bb_mobile/features/wallet/data/lwk_wallet_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_service.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bb_mobile/features/wallet/data/wallet_native_runtime.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' show Database;
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:primitives/primitives.dart' show Err, Ok;
import 'package:transaction_sync/transaction_sync.dart'
    show
        ElectrumSync,
        ReservedAddressPort,
        SyncReason,
        TransactionSyncNotFoundFailure,
        WalletConnectionPort;
import 'package:bb_mobile/features/wallet/data/wallet_catalog_port_impl.dart';

import 'package:secrets/testing.dart';

class _Native extends Mock implements WalletNativeLifecycle {}

class _Reporter extends Mock implements LoggerReporter {}

class _Bitcoin extends Mock implements BdkWalletDatasource {}

class _Liquid extends Mock implements LwkWalletDatasource {}

class _Connections extends Mock implements WalletConnectionPort {}

class _Reserved extends Mock implements ReservedAddressPort {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SqliteDatabase database;
  late WalletMetadataDatasource metadata;
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
      words:
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'
              .split(' '),
    );
    secret = (imported as Ok<Secret, SecretFailure>).value;
    row = await WalletMetadataService.deriveFromSecret(
      secret: secret,
      network: Network.bitcoinMainnet,
      scriptType: ScriptType.bip84,
      isDefault: false,
    );
    registerFallbackValue(row);
    registerFallbackValue(WalletModel.fromMetadata(row));
    descriptor =
        await WatchOnlyWalletEntity.parse(row.externalPublicDescriptor)
            as WatchOnlyDescriptorEntity;
    directory = await Directory.systemTemp.createTemp('wallet-create-');
    reporter = _Reporter();
    await initializeLogging(directory: directory, reporter: reporter);
    database = SqliteDatabase(
      NativeDatabase(File('${directory.path}/app.sqlite'), setup: _configure),
    );
    metadata = WalletMetadataDatasource(sqlite: database);
    native = _Native();
    when(() => native.prepareCreate(any())).thenAnswer((_) async {});
    final bitcoin = _Bitcoin();
    when(() => bitcoin.getBalance(wallet: any(named: 'wallet'))).thenAnswer(
      (_) async => BalanceModel(
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
      walletMetadataDatasource: metadata,
      bdkWalletDatasource: bitcoin,
      lwkWalletDatasource: _Liquid(),
      synchronize:
          (
            _, {
            discover = false,
            allowInitialScan = true,
            reason = SyncReason.auto,
          }) async {},
      isSyncing: ({walletId}) => false,
      syncStarted: const Stream.empty(),
      syncFinished: const Stream.empty(),
      electrumSyncResultStream: const Stream.empty(),
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

  test(
    'regression: unrelated settings commit during prepare does not abort import',
    () async {
      final observer = await independent();
      when(() => native.prepareCreate(any())).thenAnswer((_) async {
        await observer.customStatement('UPDATE settings SET rowid = rowid');
      });
      when(() => native.create(any())).thenAnswer((_) async {});
      try {
        await create('secret');
        verify(() => native.create(any())).called(1);
      } finally {
        await observer.close();
      }
    },
  );

  for (final path in ['secret', 'descriptor', 'xpub']) {
    test('$path rolls back failed native creation and permits retry', () async {
      final secretsBefore = Map.of(storage.entries);
      when(() => native.create(any())).thenAnswer((call) async {
        final pending = call.positionalArguments.single as WalletMetadataModel;
        expect(
          await metadata.fetch(pending.id),
          pending,
          reason: 'the writer must resolve the provisional catalog row',
        );
        throw const FileSystemException('injected native failure');
      });
      await expectLater(create(path), throwsA(isA<FileSystemException>()));
      expect(await metadata.fetchAll(), isEmpty);
      expect(
        (await log.readLogs())
            .where((line) => line.split('\t')[1] == 'WARNING')
            .map((line) => line.split('\t')[2]),
        ['Wallet creation failed catalog row removed'],
      );
      verifyZeroInteractions(reporter);
      expect(storage.entries, secretsBefore);
      when(() => native.create(any())).thenAnswer((_) async {});
      final wallet = await create(path);
      expect((await metadata.fetchAll()).single.id, wallet.id);
      expect(storage.entries, secretsBefore);
      verifyNever(() => native.delete(any()));
    });
  }

  test('real writer resolves metadata during native creation', () async {
    final runtime = WalletNativeRuntime(
      catalog: WalletCatalogPortImpl(metadata),
      reserved: _Reserved(),
      metadata: metadata,
      sync: ElectrumSync(
        connections: _Connections(),
        documentsDirectory: () async => directory.path,
        readRevision: (_) async => const Err(TransactionSyncNotFoundFailure()),
      ),
      documentsDirectory: () async => directory.path,
    );
    when(() => native.create(any())).thenAnswer(
      (call) => runtime.create(
        call.positionalArguments.single as WalletMetadataModel,
      ),
    );
    try {
      final wallet = await create('secret');
      expect((await metadata.fetchAll()).single.id, wallet.id);
    } finally {
      await runtime.close();
    }
  });

  test('another connection sees compensation after native failure', () async {
    await metadata.fetchAll();
    final observer = SqliteDatabase(
      NativeDatabase(File('${directory.path}/app.sqlite'), setup: _configure),
    );
    final observed = WalletMetadataDatasource(sqlite: observer);
    await observed.fetchAll();
    try {
      when(() => native.create(any())).thenAnswer((_) async {
        expect((await observed.fetchAll()).single.id, row.id);
        throw const FileSystemException('native failure');
      });
      await expectLater(create('secret'), throwsA(isA<FileSystemException>()));
      expect(await observed.fetchAll(), isEmpty);
    } finally {
      await observer.close();
    }
  });

  test('existing metadata survives a rejected creation', () async {
    final existing = row.copyWith(label: 'original');
    await metadata.store(existing);
    when(
      () => native.create(any()),
    ).thenThrow(const FileSystemException('injected'));
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
    });
    final rejected = expectLater(
      create('secret'),
      throwsA(isA<WalletAlreadyExistsException>()),
    );
    await prepared.future;
    final observer = await independent();
    final winner = row.copyWith(label: 'concurrent winner');
    try {
      await WalletMetadataDatasource(sqlite: observer).store(winner);
      resume.complete();
      await rejected;
      expect(await metadata.fetch(row.id), winner);
      verifyNever(() => native.create(any()));
      verifyNever(() => native.delete(any()));
    } finally {
      await observer.close();
    }
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
