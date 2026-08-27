import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart'
    show KeychainManifest;
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_manifest_import.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery_outcome.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote_identity.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_recovery_outcome_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/fetch_wallet_backup_manifest_import_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/fetch_wallet_backup_remote_identity_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/recover_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/restore_wallet_backup_manifest_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/set_wallet_backup_recovery_blocked_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/watchers/wallet_backup_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockFetchImport extends Mock
    implements FetchWalletBackupManifestImportUsecase {}

class _MockFetchIdentity extends Mock
    implements FetchWalletBackupRemoteIdentityUsecase {}

class _MockRestoreManifest extends Mock
    implements RestoreWalletBackupManifestUsecase {}

class _MockSetBlocked extends Mock
    implements SetWalletBackupRecoveryBlockedUsecase {}

class _MockOutcomes extends Mock
    implements WalletBackupRecoveryOutcomeRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockFetchImport fetchImport;
  late _MockFetchIdentity fetchIdentity;
  late _MockRestoreManifest restoreManifest;
  late _MockSetBlocked setBlocked;
  late _MockOutcomes outcomes;
  late WalletBackupCoordinator coordinator;
  late RecoverWalletBackupUsecase usecase;

  final plan = KeychainManifestImportPlan(
    KeychainManifest(
      parentFingerprint: Fingerprint('fedcba98'),
      generatedAt: 1,
      entries: const [],
    ),
  );

  setUpAll(() {
    registerFallbackValue(plan);
    registerFallbackValue(
      const WalletBackupRecoveryOutcome(
        status: WalletBackupRecoveryStatus.noBackup,
        completedAt: 0,
        restoredCount: 0,
        failedCount: 0,
      ),
    );
  });

  setUp(() {
    fetchImport = _MockFetchImport();
    fetchIdentity = _MockFetchIdentity();
    restoreManifest = _MockRestoreManifest();
    setBlocked = _MockSetBlocked();
    outcomes = _MockOutcomes();
    coordinator = WalletBackupCoordinator(
      manifestChanges: const Stream.empty(),
      syncResults: const Stream.empty(),
      publishBackup: () async => const Ok(null),
      markDirty: () async => const Ok(null),
    );
    when(
      () => setBlocked.execute(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(() => outcomes.save(any())).thenAnswer((_) async => const Ok(null));
    usecase = RecoverWalletBackupUsecase(
      fetchImport: fetchImport,
      fetchIdentity: fetchIdentity,
      restoreManifest: restoreManifest,
      setBlocked: setBlocked,
      coordinator: coordinator,
      outcomes: outcomes,
      nowUtc: () => DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
    );
  });

  tearDown(() => coordinator.dispose());

  test('clears the recovery fence when no remote backup exists', () async {
    when(() => fetchIdentity.execute()).thenAnswer((_) async => Ok(_absent()));
    when(() => fetchImport.execute()).thenAnswer((_) async => const Ok(null));

    final result = await usecase.execute();

    expect(result.status, WalletBackupRecoveryStatus.noBackup);
    verifyInOrder([
      () => setBlocked.execute(true),
      () => fetchIdentity.execute(),
      () => fetchImport.execute(),
      () => setBlocked.execute(false),
    ]);
    verify(
      () => outcomes.save(
        any(
          that: isA<WalletBackupRecoveryOutcome>().having(
            (value) => value.status,
            'status',
            WalletBackupRecoveryStatus.noBackup,
          ),
        ),
      ),
    ).called(1);
  });

  test(
    'restores one validated plan and clears the fence after a stable read',
    () async {
      final identity = _present('a');
      when(() => fetchIdentity.execute()).thenAnswer((_) async => Ok(identity));
      when(
        () => fetchImport.execute(),
      ).thenAnswer((_) async => Ok(WalletBackupManifestImport(plan: plan)));
      when(
        () => restoreManifest.execute(any(), deadline: any(named: 'deadline')),
      ).thenAnswer(
        (_) async => const WalletBackupManifestRestoreResult(
          restoredCount: 2,
          failedCount: 0,
          createdWalletIds: ['wallet-a'],
        ),
      );

      final result = await usecase.execute();

      expect(result.status, WalletBackupRecoveryStatus.restored);
      expect(result.restoredCount, 2);
      expect(result.createdWalletIds, ['wallet-a']);
      verify(() => setBlocked.execute(false)).called(1);
      verify(() => fetchIdentity.execute()).called(2);
    },
  );

  test('keeps publication blocked when the remote object changes', () async {
    var reads = 0;
    when(
      () => fetchIdentity.execute(),
    ).thenAnswer((_) async => Ok(_present(reads++ == 0 ? 'a' : 'b')));
    when(
      () => fetchImport.execute(),
    ).thenAnswer((_) async => Ok(WalletBackupManifestImport(plan: plan)));
    when(
      () => restoreManifest.execute(any(), deadline: any(named: 'deadline')),
    ).thenAnswer(
      (_) async => const WalletBackupManifestRestoreResult(
        restoredCount: 0,
        failedCount: 0,
        createdWalletIds: [],
      ),
    );

    final result = await usecase.execute();

    expect(result.status, WalletBackupRecoveryStatus.conflict);
    verifyNever(() => setBlocked.execute(false));
  });

  test(
    'reports local failure when the sanitized outcome cannot persist',
    () async {
      when(
        () => fetchIdentity.execute(),
      ).thenAnswer((_) async => Ok(_absent()));
      when(() => fetchImport.execute()).thenAnswer((_) async => const Ok(null));
      when(
        () => outcomes.save(any()),
      ).thenAnswer((_) async => const Err(WalletBackupStorageFailure()));

      final result = await usecase.execute();

      expect(result.status, WalletBackupRecoveryStatus.localFailure);
    },
  );
}

WalletBackupRemoteIdentity _absent() => WalletBackupRemoteIdentity(
  found: false,
  generation: 0,
  etag: null,
  ciphertextSha256: null,
);

WalletBackupRemoteIdentity _present(String digit) => WalletBackupRemoteIdentity(
  found: true,
  generation: 1,
  etag: digit * 64,
  ciphertextSha256: digit * 64,
);
