import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_recoverbull/src/data/attempt_monitoring_repository_impl.dart';
import 'package:bull_recoverbull/src/data/backup_metadata_repository_impl.dart';
import 'package:bull_recoverbull/src/data/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/data/secrets_vault_repository.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_key_fetch.dart';
import 'package:bull_recoverbull/src/domain/repositories/google_drive_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/key_server_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/key_server_session_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/vault_file_repository.dart';
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
import 'package:bull_recoverbull/src/ui/screens/vault_flow_page.dart';
import 'package:bull_ui/testing.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_privacy/screen_privacy.dart';
import 'package:secrets/secrets.dart' as custody;
import 'package:secrets/testing.dart';

void main() {
  for (final changeServer in [false, true]) {
    testWidgets(
      'server key is fetched once while passphrase retries stay local: $changeServer',
      (tester) async {
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

        late RecoverBullDatabase db;
        late BackupMetadataRepositoryImpl metadata;
        late VaultFlowPresentation presentation;
        late _Server server;
        late _Wallets wallets;
        late FakeSecureStoragePlatform target;
        late Fingerprint expected;
        await tester.runAsync(() async {
          FakeSecureStoragePlatform().install();
          final secrets = custody.Secrets(scratchDirectory: () async => '.');
          final imported = await secrets.import(
            words: [...List.filled(11, 'abandon'), 'about'],
            passphrase: 'synthetic-phrase',
          );
          final secret =
              (imported as Ok<custody.Secret, custody.SecretFailure>).value;
          expected = secret.id;
          final context = VaultContext(
            fingerprint: expected,
            network: BitcoinNetwork.testnet,
            hasPassphrase: true,
          );
          final vaults = SecretsVaultRepository(secrets);
          final backup =
              (await vaults.create(context)
                      as Ok<VaultBackup, RecoverBullFailure>)
                  .value;
          target = FakeSecureStoragePlatform().install();
          wallets = _Wallets();
          db = RecoverBullDatabase.forTesting(NativeDatabase.memory());
          await db.forceOpen();
          metadata = BackupMetadataRepositoryImpl(db);
          final settings =
              (await metadata.settings()
                      as Ok<BackupSettings, RecoverBullFailure>)
                  .value;
          await metadata.acceptServer(settings.server);
          final monitoring = AttemptMonitoringRepositoryImpl(db, durable: true);
          final files = _Files();
          final drive = _Drive();
          final complete = CompleteVaultUsecase(
            TestVaultUsecase(vaults, wallets),
            RestoreVaultUsecase(vaults, wallets),
            metadata,
            monitoring,
          );
          final fetch = FetchVaultKeyUsecase(monitoring);
          server = _Server(backup.key);
          final session = ManageVaultSessionUsecase(
            metadata,
            OpenKeyServerUsecase(metadata, _Sessions(server)),
            fetch,
            CreateAndStoreVaultUsecase(
              CreateVaultUsecase(vaults, wallets),
              SaveVaultUsecase(files, drive),
              metadata,
              monitoring,
              fetch,
            ),
            complete,
          );
          presentation = VaultFlowPresentation(
            VaultFlowCubit(
              ManageBackupSettingsUsecase(
                metadata,
                const VaultStorageFailure(),
              ),
              (
                pick: PickVaultUsecase(files),
                list: ListDriveVaultsUsecase(drive),
                select: ReadDriveVaultUsecase(drive),
                delete: DeleteDriveVaultUsecase(drive),
                export: ExportDriveVaultUsecase(files, drive),
              ),
              session,
              complete,
              unavailable: const VaultStorageFailure(),
              vault: backup.vault,
            ),
            const Ok(BitcoinNetwork.testnet),
            null,
          );
        });
        addTearDown(() async => db.close());
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: testBullExtensions),
            localizationsDelegates:
                RecoverBullLocalizations.localizationsDelegates,
            supportedLocales: RecoverBullLocalizations.supportedLocales,
            home: VaultFlowPage(
              flow: RecoverBullFlow.recoverVault,
              presentation: () async => presentation,
              copiedMessage: 'Copied',
            ),
          ),
        );
        await tester.runAsync(() async {
          await presentation.cubit.settings();
        });
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          'synthetic vault password',
        );
        await tester.ensureVisible(find.text('Continue'));
        await tester.runAsync(() async {
          final failure = presentation.cubit.stream.firstWhere(
            (state) => state.failure is VaultPassphraseRequiredFailure,
          );
          await tester.tap(find.text('Continue'));
          await failure;
        });
        await tester.pumpAndSettle();
        expect(find.text('Passphrase required'), findsWidgets);
        expect(server.fetches, 1);
        expect(target.entries, isEmpty);
        await tester.enterText(find.byType(TextField), 'incorrect');
        await tester.ensureVisible(find.text('Verify'));
        await tester.runAsync(() async {
          final failure = presentation.cubit.stream.firstWhere(
            (state) => state.failure is VaultPassphraseRequiredFailure,
          );
          await tester.tap(find.text('Verify'));
          await failure;
        });
        await tester.pumpAndSettle();
        expect(
          find.textContaining('does not match your backup'),
          findsOneWidget,
        );
        expect(server.fetches, 1);
        expect(target.entries, isEmpty);
        if (changeServer) {
          await tester.runAsync(() async {
            await metadata.changeServer(Uri.parse('http://other.onion'));
          });
        }
        await tester.enterText(find.byType(TextField), 'synthetic-phrase');
        await tester.ensureVisible(find.text('Verify'));
        await tester.runAsync(() async {
          final completed = presentation.cubit.stream.firstWhere(
            (state) => changeServer
                ? state.failure is VaultContextChangedFailure
                : state.completion != null,
          );
          await tester.tap(find.text('Verify'));
          await completed;
        });
        await tester.pumpAndSettle();
        expect(server.fetches, 1);
        if (changeServer) {
          expect(wallets.restores, 0);
          expect(target.entries, isEmpty);
        } else {
          expect(wallets.restores, 1);
          expect(
            presentation.cubit.state.completion?.verifiedContext?.fingerprint,
            expected,
          );
          expect(target.entries.keys, ['seed_${expected.hex}']);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(presentation.close);
      },
    );
  }
}

final class _Wallets extends Fake implements RecoverBullWalletPort {
  int restores = 0;
  @override
  Future<Result<VaultContext, RecoverBullFailure>> restoreDefaults(
    VaultContext requested,
  ) async {
    restores++;
    return Ok(requested);
  }
}

final class _Files extends Fake implements VaultFileRepository {}

final class _Drive extends Fake implements GoogleDriveRepository {}

final class _Server extends Fake implements KeyServerRepository {
  final VaultKey key;
  int fetches = 0;
  _Server(this.key);
  @override
  Future<Result<VaultKeyFetch, RecoverBullFailure>> fetch(
    EncryptedVault vault,
    String password,
  ) async {
    fetches++;
    return Ok(VaultKeyFetch(key, null));
  }

  @override
  Future<void> close() async {}
}

final class _Sessions extends Fake implements KeyServerSessionRepository {
  final _Server server;
  _Sessions(this.server);
  @override
  Future<Result<KeyServerRepository, RecoverBullFailure>> open(
    Uri server, {
    bool restartEmbedded = false,
  }) async => Ok(this.server);
}
