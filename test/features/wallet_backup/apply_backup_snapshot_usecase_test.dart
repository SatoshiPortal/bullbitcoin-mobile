import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/apply_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/restore_wallet_backup_manifest_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_definitions_section.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/wallet_metadata_backup_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import 'metadata/support/portable_settings_fixture.dart';
import 'support/fake_bullvault_backup.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_vaults_section.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_vault_entry.dart';

class _RestoreManifest extends Mock
    implements RestoreWalletBackupManifestUsecase {}

class _State extends Mock implements WalletBackupStateRepository {}

class _Definitions extends Mock implements WalletDefinitionsBackup {}

class _Vaults extends Mock implements BullVaultBackupSection {}

/// The protected-data section is a pair of plain functions now, so this is the
/// surface the test mocks and hands to the use case.
abstract interface class _MetadataSection {
  Result<void, WalletMetadataBackupFailure> validate(
    WalletMetadataSnapshot snapshot,
  );

  Future<Result<bool, WalletMetadataBackupFailure>> recover({
    required WalletMetadataSnapshot snapshot,
    required Set<String> createdWalletRefs,
    DateTime? deadline,
  });
}

class _Metadata extends Mock implements _MetadataSection {}

void main() {
  final manifest = KeychainManifest(
    parentFingerprint: Fingerprint('73c5da0a'),
    generatedAt: 1,
    entries: const [],
  );
  final metadataSnapshot = WalletMetadataSnapshot(
    labels: const [],
    frozenOutpoints: const [],
    walletPreferences: const [],
    settings: portableSettingsFixture(),
  );
  final import = WalletBackupSnapshot(
    parentFingerprint: Fingerprint('73c5da0a'),
    createdAt: 1,
    recoveryManifest: manifest,
    externalWalletDefinitions: [
      WalletDefinition(
        walletRef: 'external',
        network: Network.bitcoinMainnet,
        descriptor: 'wpkh(external)',
        provenance: WalletProvenance.watchOnly,
      ),
    ],
    metadata: metadataSnapshot,
  );

  setUpAll(() {
    registerFallbackValue(manifest);
    registerFallbackValue(metadataSnapshot);
    registerFallbackValue(const <WalletDefinition>[]);
    registerFallbackValue(const <WalletBackupVaultEntry>[]);
    registerFallbackValue(WalletBackupRecoveryStatus.noBackup);
    registerFallbackValue(WalletBackupRecoveryState.idle);
  });

  late _RestoreManifest restore;
  late _State state;
  late _Definitions definitions;
  late _Metadata metadata;
  late List<String> calls;
  late WalletBackupRecoveryState fence;
  late ApplyBackupSnapshotUsecase usecase;
  late FakeBullVaultBackupSection vaults;

  setUp(() {
    restore = _RestoreManifest();
    state = _State();
    definitions = _Definitions();
    metadata = _Metadata();
    calls = [];
    fence = WalletBackupRecoveryState.idle;

    when(() => metadata.validate(any())).thenReturn(const Ok(null));
    when(
      () => restore.execute(any(), deadline: any(named: 'deadline')),
    ).thenAnswer((_) async {
      calls.add('manifest');
      return const WalletBackupManifestRestoreResult(
        restoredCount: 1,
        failedCount: 0,
      );
    });
    when(
      () => definitions.recover(
        definitions: any(named: 'definitions'),
        deadline: any(named: 'deadline'),
      ),
    ).thenAnswer((_) async {
      calls.add('definitions');
      return Ok(
        WalletDefinitionsRecoveryResult(
          restoredCount: 1,
          failedCount: 0,
          createdWalletRefs: ['external'],
        ),
      );
    });
    when(
      () => metadata.recover(
        snapshot: any(named: 'snapshot'),
        createdWalletRefs: any(named: 'createdWalletRefs'),
        deadline: any(named: 'deadline'),
      ),
    ).thenAnswer((_) async {
      calls.add('metadata');
      return const Ok(true);
    });
    when(
      () => state.saveRemoteCheckpoint(null),
    ).thenAnswer((_) async => const Ok(null));
    when(() => state.setRecoveryState(any())).thenAnswer((invocation) async {
      fence =
          invocation.positionalArguments.single as WalletBackupRecoveryState;
      calls.add(fence.name);
      return const Ok(null);
    });
    when(() => state.get()).thenAnswer(
      (_) async => Ok(
        WalletBackupState(
          enabled: true,
          localRevision: 1,
          uploadedRevision: 0,
          lastSucceededAt: null,
          unsupportedVersion: null,
          recoveryState: fence,
        ),
      ),
    );
    when(() => state.saveRecoveryOutcome(any())).thenAnswer((_) async {
      calls.add('outcome');
      return const Ok(null);
    });

    vaults = FakeBullVaultBackupSection();
    usecase = ApplyBackupSnapshotUsecase(
      state,
      definitions,
      vaults,
      restoreManifest: restore,
      validateMetadata: metadata.validate,
      restoreMetadata: metadata.recover,
      nowUtc: () => DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
    );
  });

  test('validates before mutation and restores in dependency order', () async {
    final result = await usecase.execute(snapshot: Ok(import));

    expect(result.status, WalletBackupRecoveryStatus.restored);
    expect(result.restoredCount, 2);
    expect(calls, [
      'applying',
      'manifest',
      'definitions',
      'metadata',
      'idle',
      'outcome',
    ]);
    verify(
      () => metadata.recover(
        snapshot: metadataSnapshot,
        createdWalletRefs: {'external'},
        deadline: any(named: 'deadline'),
      ),
    ).called(1);
  });

  test('rejects an invalid section before fencing or restoring', () async {
    when(
      () => metadata.validate(metadataSnapshot),
    ).thenReturn(const Err(WalletMetadataBackupEncodingFailure()));

    final result = await usecase.execute(snapshot: Ok(import));

    expect(result.status, WalletBackupRecoveryStatus.invalid);
    expect(calls, ['outcome']);
    verifyNever(() => restore.execute(any(), deadline: any(named: 'deadline')));
  });

  test('a partial restore ends at needs-attention', () async {
    when(
      () => metadata.recover(
        snapshot: any(named: 'snapshot'),
        createdWalletRefs: any(named: 'createdWalletRefs'),
        deadline: any(named: 'deadline'),
      ),
    ).thenAnswer((_) async {
      calls.add('metadata');
      return const Ok(false);
    });

    final result = await usecase.execute(snapshot: Ok(import));

    expect(result.status, WalletBackupRecoveryStatus.partiallyRestored);
    expect(fence, WalletBackupRecoveryState.needsAttention);
    expect(calls, isNot(contains('idle')));
  });

  test('an unreachable remote is recorded without fencing anything', () async {
    final result = await usecase.execute(
      snapshot: const Err(WalletBackupRemoteUnavailableFailure()),
    );

    expect(result.status, WalletBackupRecoveryStatus.unavailable);
    expect(calls, ['outcome']);
    verifyNever(() => restore.execute(any(), deadline: any(named: 'deadline')));
  });

  test('a post-apply conflict ends at needs-attention', () async {
    final result = await usecase.execute(
      snapshot: Ok(import),
      revalidate: () async => const Ok(false),
    );

    expect(result.status, WalletBackupRecoveryStatus.conflict);
    expect(fence, WalletBackupRecoveryState.needsAttention);
    expect(calls, isNot(contains('idle')));
  });

  test('a budget already spent stops before it restores anything', () async {
    final result = await usecase.execute(
      snapshot: Ok(import),
      deadline: DateTime.fromMillisecondsSinceEpoch(500, isUtc: true),
    );

    expect(result.status, WalletBackupRecoveryStatus.timedOut);
    expect(result.restoredCount, 0);
    // The fence went up and stayed up: a run that gave up part-way is not a
    // run that finished.
    expect(fence, WalletBackupRecoveryState.needsAttention);
    expect(calls, ['applying', 'needsAttention', 'outcome']);
    verifyNever(() => restore.execute(any(), deadline: any(named: 'deadline')));
    verifyNever(
      () => definitions.recover(
        definitions: any(named: 'definitions'),
        deadline: any(named: 'deadline'),
      ),
    );
    verifyNever(
      () => metadata.recover(
        snapshot: any(named: 'snapshot'),
        createdWalletRefs: any(named: 'createdWalletRefs'),
        deadline: any(named: 'deadline'),
      ),
    );
  });

  test('a caller that settles the fence itself is left holding it', () async {
    final applied = await usecase.execute(
      snapshot: Ok(import),
      callerSettlesFence: true,
    );

    expect(applied.status, WalletBackupRecoveryStatus.restored);
    expect(fence, WalletBackupRecoveryState.applying);
    expect(calls, isNot(contains('outcome')));

    await usecase.settle(applied, fence: WalletBackupRecoveryState.idle);

    expect(fence, WalletBackupRecoveryState.idle);
    expect(calls.last, 'outcome');
  });

  group('vaults', () {
    late _Vaults vaultsMock;
    late WalletBackupSnapshot withVault;

    setUp(() {
      vaultsMock = _Vaults();
      withVault = WalletBackupSnapshot(
        parentFingerprint: import.parentFingerprint,
        createdAt: import.createdAt,
        recoveryManifest: import.recoveryManifest,
        externalWalletDefinitions: import.externalWalletDefinitions,
        vaults: [fakeVaultEntry(walletRef: 'vault-wallet', label: 'Vault')],
        metadata: import.metadata,
      );
      when(
        () => vaultsMock.recover(any(), deadline: any(named: 'deadline')),
      ).thenAnswer((_) async {
        calls.add('vaults');
        return Ok(
          WalletVaultsRecoveryResult(
            restoredCount: 1,
            skippedCount: 0,
            failedCount: 0,
            createdWalletRefs: ['vault-wallet'],
          ),
        );
      });
      usecase = ApplyBackupSnapshotUsecase(
        state,
        definitions,
        vaultsMock,
        restoreManifest: restore,
        validateMetadata: metadata.validate,
        restoreMetadata: metadata.recover,
        nowUtc: () => DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      );
    });

    test('are replayed after definitions and before metadata', () async {
      final result = await usecase.execute(snapshot: Ok(withVault));

      expect(result.status, WalletBackupRecoveryStatus.restored);
      expect(result.restoredCount, 3);
      expect(
        calls.where((call) => !['applying', 'idle', 'outcome'].contains(call)),
        ['manifest', 'definitions', 'vaults', 'metadata'],
      );
      final created =
          verify(
                () => metadata.recover(
                  snapshot: any(named: 'snapshot'),
                  createdWalletRefs: captureAny(named: 'createdWalletRefs'),
                  deadline: any(named: 'deadline'),
                ),
              ).captured.single
              as Set<String>;
      expect(created, containsAll(['external', 'vault-wallet']));
    });

    test('are not touched when the document has none', () async {
      await usecase.execute(snapshot: Ok(import));

      verifyNever(
        () => vaultsMock.recover(any(), deadline: any(named: 'deadline')),
      );
    });

    test(
      'a vault that fails to restore leaves recovery needing attention',
      () async {
        when(
          () => vaultsMock.recover(any(), deadline: any(named: 'deadline')),
        ).thenAnswer(
          (_) async => Ok(
            WalletVaultsRecoveryResult(
              restoredCount: 0,
              skippedCount: 0,
              failedCount: 1,
              createdWalletRefs: const [],
            ),
          ),
        );

        final result = await usecase.execute(snapshot: Ok(withVault));

        expect(result.status, WalletBackupRecoveryStatus.partiallyRestored);
        expect(result.failedCount, 1);
        expect(fence, WalletBackupRecoveryState.needsAttention);
      },
    );
  });
}
