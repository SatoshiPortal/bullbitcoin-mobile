import 'dart:async';
import 'package:bb_mobile/core/bip85/data/bip85_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/wallet_backup_snapshot_repository_impl.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/bullvault_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_metadata_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/build_wallet_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../backup_snapshot_fixture.dart';

class _Identity extends Mock implements NostrIdentityFacade {}

class _Manifest extends Mock implements KeychainManifestFacade {}

class _Metadata extends Mock implements WalletMetadataBackupRepository {}

class _Vaults extends Mock implements BullVaultBackupRepository {}

void main() {
  final credential = BackupCredential.fromWords(backupFixtureWords);
  final fixture = backupSnapshotFixture(credential);
  late SqliteDatabase db;
  late _Manifest manifest;
  late _Identity identity;
  late _Metadata metadata;
  late _Vaults vaults;
  late BuildWalletBackupSnapshotUsecase build;
  late WalletBackupSnapshotRepositoryImpl repository;
  late StreamController<void> changes;
  setUpAll(() => registerFallbackValue(credential));
  setUp(() {
    db = SqliteDatabase(NativeDatabase.memory());
    manifest = _Manifest();
    metadata = _Metadata();
    vaults = _Vaults();
    changes = StreamController<void>.broadcast();
    when(() => manifest.capture(any())).thenAnswer(
      (_) async => Ok(
        CapturedKeychainManifest(
          manifest: fixture.manifest,
          walletReferences: {'source-wallet': 'source-wallet'},
        ),
      ),
    );
    when(
      () => metadata.capture(any()),
    ).thenAnswer((_) async => Ok(fixture.metadata));
    when(() => vaults.capture(any())).thenAnswer((_) async => const Ok([]));
    when(() => metadata.changes).thenAnswer((_) => changes.stream);
    when(() => vaults.changes).thenAnswer((_) => const Stream.empty());
    when(manifest.watchNostrKeys).thenAnswer((_) => const Stream.empty());
    repository = WalletBackupSnapshotRepositoryImpl(
      database: db,
      manifest: manifest,
      metadata: metadata,
      vaults: vaults,
      wallets: WalletMetadataDatasource(sqlite: db),
      bip85: Bip85Datasource(sqlite: db),
    );
    identity = _Identity();
    when(identity.resolve).thenAnswer((_) async => Ok(credential));
    build = BuildWalletBackupSnapshotUsecase(repository, identity);
  });
  tearDown(() async {
    await changes.close();
    await db.close();
  });
  test(
    'one capture uses the same manifest references for metadata and vaults',
    () async {
      final snapshot =
          (await build.execute()
                  as Ok<WalletBackupSnapshot, WalletBackupFailure>)
              .value;
      expect(snapshot.manifest, same(fixture.manifest));
      expect(snapshot.metadata, same(fixture.metadata));
      verify(
        () => metadata.capture({'source-wallet': 'source-wallet'}),
      ).called(1);
      verify(
        () => vaults.capture({'source-wallet': 'source-wallet'}),
      ).called(1);
    },
  );
  test('a failed owner cannot become an empty successful backup', () async {
    when(
      () => manifest.capture(any()),
    ).thenAnswer((_) async => const Err(KeychainManifestStorageFailure()));
    expect(await build.execute(), isA<Err>());
    verifyNever(() => metadata.capture(any()));
    when(() => manifest.capture(any())).thenAnswer(
      (_) async => Ok(
        CapturedKeychainManifest(
          manifest: fixture.manifest,
          walletReferences: {'source-wallet': 'source-wallet'},
        ),
      ),
    );
    when(
      () => metadata.capture(any()),
    ).thenAnswer((_) async => const Err(WalletBackupIncompleteFailure()));
    expect(await build.execute(), isA<Err>());
  });
  test(
    'local preview resolves only at the explicit capture and fails without capture when unavailable',
    () async {
      verifyZeroInteractions(identity);
      when(
        identity.resolve,
      ).thenAnswer((_) async => const Err(InvalidDataRecoveryWords()));
      expect(
        await build.execute(),
        isA<Err<WalletBackupSnapshot, WalletBackupFailure>>(),
      );
      verifyNever(() => manifest.capture(any()));
    },
  );
  test('owner invalidations reach the snapshot watcher', () async {
    final invalidated = WatchWalletBackupSnapshotUsecase(
      repository,
    ).execute().first;
    changes.add(null);
    await invalidated;
  });
}
