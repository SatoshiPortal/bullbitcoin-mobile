import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_metadata_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_inventory_backup_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/data_backup_status.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_data_backup_usecase.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_codec_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/manage_wallet_backup_state_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/publish_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/features/wallet_backup/wallet_backup_locator.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _Identity extends Mock implements NostrIdentityFacade {}

class _Vaults extends Mock implements BullVaultFacade {}

class _Snapshots extends Fake implements WalletBackupCodecRepository {}

class _Catalog extends Mock implements KeychainManifestFacade {}

class _Wallets extends Fake implements WalletInventoryBackupRepository {}

class _Metadata extends Fake implements WalletMetadataBackupRepository {}

class _Files extends Fake implements WalletBackupFileRepository {}

class _Publish extends Mock implements PublishWalletBackupUsecase {}

void main() {
  late GetIt services;
  late SqliteDatabase database;
  late _Identity identity;
  setUp(() async {
    services = GetIt.asNewInstance();
    database = SqliteDatabase(NativeDatabase.memory());
    identity = _Identity();
    services.registerSingleton<SqliteDatabase>(database);
    services.registerSingleton<NostrIdentityFacade>(identity);
    services.registerSingleton<BullVaultFacade>(_Vaults());
    services.registerSingleton<KeychainManifestFacade>(_Catalog());
    WalletBackupLocator.setup(services);
    await services.unregister<WalletBackupFileRepository>();
    services.registerSingleton<WalletBackupFileRepository>(_Files());
    await services.unregister<WalletBackupCodecRepository>();
    services.registerSingleton<WalletBackupCodecRepository>(_Snapshots());
    await services.unregister<WalletInventoryBackupRepository>();
    await services.unregister<WalletMetadataBackupRepository>();
    services.registerSingleton<WalletInventoryBackupRepository>(_Wallets());
    services.registerSingleton<WalletMetadataBackupRepository>(_Metadata());
  });
  tearDown(() async {
    await services.reset();
    await database.close();
  });
  test('all screens share the consent request owner', () {
    expect(
      services<SetWalletBackupEnabledUsecase>(),
      same(services<SetWalletBackupEnabledUsecase>()),
    );
  });

  test('manual publication updates the same status read by settings', () async {
    final publish = _Publish();
    await services.unregister<PublishWalletBackupUsecase>();
    services.registerSingleton<PublishWalletBackupUsecase>(publish);
    final facade = services<WalletBackupFacade>();
    when(
      () => publish.execute(force: true),
    ).thenAnswer((_) async => const Err(WalletBackupNetworkFailure()));
    expect(await facade.publish(force: true), isA<Err>());
    expect(facade.publicationStatus.result, isA<Err>());
    when(
      () => publish.execute(force: true),
    ).thenAnswer((_) async => const Ok(WalletBackupPublication.published));
    expect(await facade.publish(force: true), isA<Ok>());
    expect(facade.publicationStatus.result, isA<Ok>());
    expect(facade.publicationStatus.running, isFalse);
  });
  test(
    'opening control keeps the undecided choice without a credential lookup',
    () async {
      final facade = services<WalletBackupFacade>();
      final result = await facade.getControl();
      final control =
          (result as Ok<WalletBackupControl, WalletBackupFailure>).value;
      expect(control.enabled, isNull);
      expect(control.recoveryIncomplete, isFalse);
      verifyZeroInteractions(identity);
    },
  );
  test(
    'off survives subsequent reads and publication never reads identity or inventory',
    () async {
      expect(
        await services<SetWalletBackupEnabledUsecase>().execute(false),
        isA<Ok>(),
      );
      final publication = await services<PublishWalletBackupUsecase>()
          .execute();
      expect(
        (publication as Ok<WalletBackupPublication, WalletBackupFailure>).value,
        WalletBackupPublication.inactive,
      );
      final control = await services<WalletBackupFacade>().getControl();
      expect(
        (control as Ok<WalletBackupControl, WalletBackupFailure>).value.enabled,
        isFalse,
      );
      verifyZeroInteractions(identity);
    },
  );
  test(
    'off status reads the newest stored date without resolving the seed',
    () async {
      when(
        identity.resolve,
      ).thenAnswer((_) async => const Err(BackupCredentialUnavailable()));
      final state = services<WalletBackupStateRepository>();
      expect(await state.setEnabled(false), isA<Ok>());
      final load = LoadDataBackupStatusUsecase(services<WalletBackupFacade>());
      final empty =
          (await load.execute() as Ok<DataBackupStatus, BackupSettingsFailure>)
              .value;
      expect(empty.control.enabled, isFalse);
      expect(empty.lastSuccessAt, isNull);
      verifyZeroInteractions(identity);

      final latest = DateTime.utc(2026, 9, 20);
      for (final (key, date) in [
        ('a' * 64, latest),
        ('b' * 64, latest.subtract(const Duration(days: 1))),
      ]) {
        expect(
          await state.recordPublication(
            identity: key,
            expectedEtag: null,
            checkpoint: WalletBackupCheckpoint(
              generation: 1,
              etag: '1' * 64,
              ciphertextHash: '2' * 64,
            ),
            contentHash: '3' * 64,
            succeededAt: date,
          ),
          isA<Ok>(),
        );
      }
      final result =
          (await load.execute(retryPublication: true)
                  as Ok<DataBackupStatus, BackupSettingsFailure>)
              .value;
      expect(result.control.enabled, isFalse);
      expect(result.lastSuccessAt, latest);
      expect(result.failure, isNull);
      expect(result.publication, isNull);
      expect(result.publishing, isFalse);
      verifyZeroInteractions(identity);
    },
  );
  test(
    'an explicit words check uses the supplied credential path and invalid input makes no request',
    () async {
      when(
        () => identity.fromWords('invalid'),
      ).thenReturn(const Err(InvalidDataRecoveryWords()));
      final result = await services<WalletBackupFacade>().recoverVaults(
        words: 'invalid',
      );
      expect(result, isA<Err<VaultBackupRecovery?, WalletBackupFailure>>());
      verify(() => identity.fromWords('invalid')).called(1);
      verifyNever(identity.resolve);
    },
  );
}
