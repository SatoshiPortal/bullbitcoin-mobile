import 'dart:async';
import 'dart:convert';

import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_recoverbull/src/data/attempt_monitoring_repository_impl.dart';
import 'package:bull_recoverbull/src/data/backup_metadata_repository_impl.dart';
import 'package:bull_recoverbull/src/data/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/data/secrets_vault_repository.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_key_fetch.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_provider.dart';
import 'package:bull_recoverbull/src/domain/repositories/google_drive_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/key_server_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/key_server_session_repository.dart';
import 'package:file_system/file_system.dart';
import 'package:bull_recoverbull/src/data/mappers/encrypted_vault_mapper.dart';
import 'package:bull_recoverbull/src/domain/usecases/complete_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/create_and_store_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/create_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/delete_drive_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/export_drive_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/fetch_vault_key_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/list_drive_vaults_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/manage_backup_settings_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/manage_vault_session_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/open_key_server_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/pick_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/read_drive_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/restore_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/save_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/test_vault_usecase.dart';
import 'package:bull_recoverbull/src/presentation/vault_flow_cubit.dart';
import 'package:bull_recoverbull/src/presentation/vault_flow_presentation.dart';
import 'package:bull_recoverbull/src/ui/pages/vault_provider_selection_page.dart';
import 'package:bull_recoverbull/src/ui/recoverbull_flow_navigator.dart';
import 'package:bull_ui/testing.dart';
import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show Failure;
import 'package:screen_privacy/screen_privacy.dart';
import 'package:secrets/secrets.dart' as custody;
import 'package:secrets/testing.dart';

void main() {
  final context = VaultContext(
    fingerprint: Fingerprint('73c5da0a'),
    network: BitcoinNetwork.testnet,
  );
  late RecoverBullDatabase database;
  late BackupMetadataRepositoryImpl metadata;
  late AttemptMonitoringRepositoryImpl monitoring;
  late SecretsVaultRepository vaults;
  late _Wallets wallets;
  late _Files files;
  late _Server server;
  late BackupSettings settings;
  late CreateAndStoreVaultUsecase create;
  late CompleteVaultUsecase complete;

  setUp(() async {
    FakeSecureStoragePlatform().install();
    final secrets = custody.Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => '.',
    );
    // Published BIP39 test vector.
    ok(
      await secrets.import(
        words: '${'abandon ' * 11}about'.split(' '),
        language: custody.Language.english,
      ),
    );
    vaults = SecretsVaultRepository(secrets);
    wallets = _Wallets(context);
    files = _Files();
    server = _Server();
    database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await database.forceOpen();
    metadata = BackupMetadataRepositoryImpl(database);
    monitoring = AttemptMonitoringRepositoryImpl(database, durable: true);
    settings = ok(await metadata.settings());
    ok(await metadata.acceptServer(settings.server));
    settings = ok(await metadata.settings());
    create = CreateAndStoreVaultUsecase(
      CreateVaultUsecase(vaults, wallets),
      SaveVaultUsecase(files, _Drive()),
      metadata,
      monitoring,
      FetchVaultKeyUsecase(monitoring),
    );
    complete = CompleteVaultUsecase(
      TestVaultUsecase(vaults, wallets),
      RestoreVaultUsecase(vaults, wallets),
      metadata,
      monitoring,
    );
  });
  tearDown(() => database.close());

  Future<Result<VaultCompletion, RecoverBullFailure>> save() => create.execute(
    settings: settings,
    server: server,
    provider: VaultProvider.customLocation,
    password: 'public test password',
  );

  test('pending provider save rejects a replacement password', () async {
    final first = save();
    await files.started.future;
    files.pending.complete(const Ok(false));
    expect(await first, isA<Err<VaultCompletion, RecoverBullFailure>>());
    files.pending = Completer<Result<bool, FileSystemFailure>>()
      ..complete(const Ok(true));
    final retried = await create.execute(
      settings: settings,
      server: server,
      provider: VaultProvider.customLocation,
      password: 'replacement password',
    );
    expect(
      retried,
      isA<Err<VaultCompletion, RecoverBullFailure>>(),
      reason: 'A pending save must not silently accept a new password',
    );
    expect(files.calls, 1);
    expect(create.hasPendingProviderSave, isTrue);
    final saved = ok(
      await create.retryProviderSave(VaultProvider.customLocation),
    );
    expect(create.hasPendingProviderSave, isFalse);
    final content = EncryptedVaultMapper.fromEntity(saved.vault).toFile();
    expect(files.savedContents, [content, content]);
    expect(server.storedPassword, 'public test password');
    expect(server.stores, 1);
    expect(server.trashed, 0);
  });

  test('a retry saves where the user first chose', () async {
    final first = save();
    await files.started.future;
    files.pending.complete(const Ok(false));
    await first;
    files.pending = Completer<Result<bool, FileSystemFailure>>()
      ..complete(const Ok(true));

    ok(await create.retryProviderSave());
    expect(files.calls, 2);
    expect(create.hasPendingProviderSave, isFalse);
  });

  test(
    'a discarded pending save lets a new password seal a new vault',
    () async {
      final first = save();
      await files.started.future;
      files.pending.complete(const Ok(false));
      await first;

      expect(create.abandonPendingProviderSave(), isTrue);
      expect(create.hasPendingProviderSave, isFalse);
      files.pending = Completer<Result<bool, FileSystemFailure>>()
        ..complete(const Ok(true));
      ok(
        await create.execute(
          settings: settings,
          server: server,
          provider: VaultProvider.customLocation,
          password: 'replacement password',
        ),
      );
      expect(server.storedPassword, 'replacement password');
      expect(server.stores, 2);
    },
  );

  for (final result in [
    const Ok<bool, FileSystemFailure>(false),
    const Err<bool, FileSystemFailure>(FileSystemSaveFailure()),
  ]) {
    testWidgets('provider ${result.runtimeType} offers save-only retry', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      const channel = MethodChannel('com.flutterplaza.no_screenshot_methods');
      ScreenCaptureProtection.instance.enabledByUser = true;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => true,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final sealing = SealingPassword('public test password');
      final sessions = _Sessions(server);
      final session = ManageVaultSessionUsecase(
        metadata,
        OpenKeyServerUsecase(metadata, sessions),
        FetchVaultKeyUsecase(monitoring),
        create,
        complete,
      );
      final cubit = VaultFlowCubit(
        ManageBackupSettingsUsecase(metadata, const VaultStorageFailure()),
        (
          pick: PickVaultUsecase(files),
          list: ListDriveVaultsUsecase(_Drive()),
          select: ReadDriveVaultUsecase(_Drive()),
          delete: DeleteDriveVaultUsecase(_Drive()),
          export: ExportDriveVaultUsecase(files, _Drive()),
        ),
        session,
        complete,
        unavailable: const VaultStorageFailure(),
      );
      final presentation = VaultFlowPresentation(
        cubit,
        const Ok(BitcoinNetwork.testnet),
        null,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: testBullExtensions),
          localizationsDelegates: RecoverBullFeature.localizationsDelegates,
          supportedLocales: RecoverBullLocalizations.supportedLocales,
          home: RecoverBullFlowHost(
            flow: RecoverBullFlow.secureVault,
            presentation: presentation,
            page: VaultProviderSelectionPage(password: sealing),
            copiedMessage: 'Copied',
            onTestVault: () {},
            onFinished: () {},
          ),
        ),
      );
      await tester.runAsync(() async {
        await cubit.settings();
      });
      await tester.pumpAndSettle();
      expect(find.text('Custom location'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Custom location'));
        await files.started.future;
        files.pending.complete(result);
        // Wait for the real flow result, not a fabricated cubit state.
        await cubit.stream.firstWhere((state) => !state.busy);
      });
      await tester.pumpAndSettle();
      expect(find.text('Custom location'), findsNothing);
      expect(find.text('Retry saving backup'), findsOneWidget);
      expect(
        find.textContaining('password you already confirmed'),
        findsOneWidget,
      );
      expect(cubit.state.hasPendingProviderSave, isTrue);
      // Sealed: the retry saves the same vault, so the screen forgets the password.
      expect(sealing.value, isNull);
      // A changed consent generation must not cause the save-only retry to
      // acquire another server session. The pending file keeps its old key.
      await tester.runAsync(
        () => metadata.changeServer(Uri.parse('https://other.example')),
      );
      await tester.runAsync(() async {
        final rejected = await session.create(
          provider: VaultProvider.customLocation,
          password: 'replacement password',
        );
        expect(rejected, isA<Err<VaultCompletion, RecoverBullFailure>>());
      });
      expect(sessions.opens, 1);
      expect(files.calls, 1);
      await tester.ensureVisible(find.text('Retry saving backup'));
      await tester.runAsync(() async {
        // Complete the simulated picker in the async zone that awaits it.
        files.pending = Completer<Result<bool, FileSystemFailure>>()
          ..complete(const Ok(true));
        final completed = cubit.stream.firstWhere(
          (state) => state.completion != null,
        );
        await tester.tap(find.text('Retry saving backup'));
        await completed;
      });
      await tester.pumpAndSettle();
      expect(cubit.state.hasPendingProviderSave, isFalse);
      expect(cubit.state.completion, isNotNull);
      expect(files.savedContents, [
        files.savedContents.first,
        files.savedContents.first,
      ]);
      expect(server.storedPassword, 'public test password');
      expect(server.stores, 1);
      expect(sessions.opens, 1);
      // Let the snack bars dismiss themselves before the tree is torn down.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(presentation.close);
      expect(server.trashed, 0);
    });
  }

  test('close during store cleans up through the durable journal', () async {
    server.pendingStore = Completer();
    final saving = save();
    await server.started.future;
    create.close();
    server.pendingStore?.complete(const Ok(null));
    expect(await saving, isA<Err<VaultCompletion, RecoverBullFailure>>());
    expect(server.trashed, 1);
    expect(files.calls, 0);
  });

  test('failed cleanup admission retains the server key', () async {
    server.pendingStore = Completer();
    final saving = save();
    await server.started.future;
    await database.customStatement(
      "CREATE TRIGGER reject_journal BEFORE INSERT ON recoverbull_own_operations BEGIN SELECT RAISE(FAIL, 'test write failure'); END",
    );
    create.close();
    server.pendingStore?.complete(const Ok(null));
    await saving;
    expect(server.trashed, 0);
  });

  for (final succeeds in [true, false]) {
    test(
      'close during provider save preserves its real result: $succeeds',
      () async {
        final saving = save();
        await files.started.future;
        create.close();
        files.pending.complete(Ok(succeeds));
        final result = await saving;
        expect(result is Ok, succeeds);
        expect(server.trashed, 0);
        final status = ok(await metadata.status(context));
        expect(status.storedAt != null, succeeds);
        expect(status.isVerified, isFalse);
      },
    );
  }

  test(
    'manual recovery succeeds with an unreadable metadata database',
    () async {
      final backup = ok(await vaults.create(context));
      await database.customStatement('DROP TABLE recoverbull_state');
      final result = ok(
        await complete.execute(
          vault: backup.vault,
          key: backup.key,
          recoveryNetwork: context.network,
          cancelled: () => false,
        ),
      );
      expect(result.recovery, isA<VaultRecovered>());
      expect(result.warning, isNotNull);
      expect(wallets.restores, 1);
      expect(server.trashed, 0);
    },
  );

  test(
    'manual recovery exists even when no metadata connection opened',
    () async {
      final backup = ok(await vaults.create(context));
      final manual = CompleteVaultUsecase(
        TestVaultUsecase(vaults, wallets),
        RestoreVaultUsecase(vaults, wallets),
        null,
        null,
        unavailableFailure: const VaultStorageFailure(),
      );
      final result = ok(
        await manual.execute(
          vault: backup.vault,
          key: backup.key,
          recoveryNetwork: context.network,
          cancelled: () => false,
        ),
      );
      expect(result.recovery, isA<VaultRecovered>());
      expect(result.warning, isA<VaultStorageFailure>());
    },
  );

  test('completed test certifies only its actual context', () async {
    final backup = ok(await vaults.create(context));
    final result = ok(
      await complete.execute(
        vault: backup.vault,
        key: backup.key,
        recoveryNetwork: null,
        cancelled: () => false,
      ),
    );
    expect(result.warning, isNull);
    expect(ok(await metadata.status(context)).isVerified, isTrue);
    expect(
      ok(
        await metadata.status(
          VaultContext(
            fingerprint: context.fingerprint,
            network: BitcoinNetwork.mainnet,
          ),
        ),
      ).isVerified,
      isFalse,
    );
    expect(wallets.restores, 0);
  });

  test(
    'closing a pending fetch prevents import and waits to close its route',
    () async {
      final backup = ok(await vaults.create(context));
      final sessions = _Sessions(server);
      final flow = ManageVaultSessionUsecase(
        metadata,
        OpenKeyServerUsecase(metadata, sessions),
        FetchVaultKeyUsecase(monitoring),
        create,
        complete,
      );
      expect(sessions.opens, 0, reason: 'construction must remain idle');
      final fetching = flow.verify(
        vault: backup.vault,
        password: 'test password',
        recoveryNetwork: context.network,
      );
      await server.fetchStarted.future;
      final closing = flow.close();
      expect(server.closes, 0);
      server.pendingFetch.complete(Ok(VaultKeyFetch(backup.key, null)));
      expect(await fetching, isA<Err<VaultCompletion, RecoverBullFailure>>());
      await closing;
      await flow.close();
      expect(wallets.restores, 0);
      expect(server.closes, 1);
      expect(ok(await metadata.status(context)).isVerified, isFalse);
    },
  );
}

T ok<T, F extends Failure>(Result<T, F> result) => (result as Ok<T, F>).value;

final class _Wallets implements RecoverBullWalletPort {
  final VaultContext context;
  int restores = 0;
  _Wallets(this.context);
  @override
  Future<Result<VaultContext?, RecoverBullFailure>> currentDefault() async =>
      Ok(context);
  @override
  Future<Result<VaultContext, RecoverBullFailure>> restoreDefaults(
    VaultContext requested,
  ) async {
    restores++;
    return Ok(requested);
  }
}

final class _Files extends Fake implements FileSystem {
  int calls = 0;
  final savedContents = <String>[];
  final started = Completer<void>();
  var pending = Completer<Result<bool, FileSystemFailure>>();
  @override
  Future<Result<bool, FileSystemFailure>> save({
    required String filename,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
  }) {
    calls++;
    savedContents.add(utf8.decode(bytes));
    if (!started.isCompleted) started.complete();
    return pending.future;
  }
}

final class _Drive extends Fake implements GoogleDriveRepository {}

final class _Server extends Fake implements KeyServerRepository {
  final started = Completer<void>();
  Completer<Result<void, RecoverBullFailure>>? pendingStore;
  int trashed = 0;
  int stores = 0;
  String? storedPassword;
  int closes = 0;
  final fetchStarted = Completer<void>();
  final pendingFetch = Completer<Result<VaultKeyFetch, RecoverBullFailure>>();
  @override
  Future<void> close() async {
    closes++;
  }

  @override
  Future<Result<VaultKeyFetch, RecoverBullFailure>> fetch(
    EncryptedVault vault,
    String password,
  ) {
    fetchStarted.complete();
    return pendingFetch.future;
  }

  @override
  Future<Result<void, RecoverBullFailure>> store(
    EncryptedVault vault,
    String password,
    VaultKey key,
  ) {
    stores++;
    storedPassword = password;
    if (!started.isCompleted) started.complete();
    return pendingStore?.future ?? Future.value(const Ok(null));
  }

  @override
  Future<Result<VaultKeyFetch, RecoverBullFailure>> trash(
    EncryptedVault vault,
    String password,
  ) async {
    trashed++;
    return Ok(VaultKeyFetch(VaultKey('11' * 32), null));
  }
}

final class _Sessions implements KeyServerSessionRepository {
  final _Server server;
  int opens = 0;
  _Sessions(this.server);
  @override
  Future<Result<KeyServerRepository, RecoverBullFailure>> open(
    Uri server, {
    bool restartEmbedded = false,
    bool viaSnowflake = false,
  }) async {
    opens++;
    return Ok(this.server);
  }
}
