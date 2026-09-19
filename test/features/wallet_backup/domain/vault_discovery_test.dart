import 'dart:async';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/bullvault_backup_entry.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_ciphertext.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote_head.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_inventory_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/bullvault_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_codec_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/inspect_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/manage_bullvault_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_operation_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../backup_snapshot_fixture.dart';
import '../../bullvault/bullvault_test_fixture.dart';

class _Identity extends Mock implements NostrIdentityFacade {}

class _Remote extends Mock implements WalletBackupRemoteRepository {}

class _Codec extends Mock implements WalletBackupCodecRepository {}

class _Vaults extends Mock implements BullVaultBackupRepository {}

class _State extends Fake implements WalletBackupStateRepository {
  bool incomplete = false;
  final writes = <bool>[];
  @override
  Future<Result<WalletBackupControl, WalletBackupFailure>> getControl() async =>
      Ok(WalletBackupControl(enabled: false, recoveryIncomplete: incomplete));
  @override
  Future<Result<void, WalletBackupFailure>> setRecoveryIncomplete(
    bool value,
  ) async {
    writes.add(value);
    incomplete = value;
    return const Ok(null);
  }
}

void main() {
  final credential = BackupCredential.fromWords(backupFixtureWords);
  final base = backupSnapshotFixture(credential);
  final vault = testBullVaultCreateResult(walletId: 'vault-source');
  final snapshot = WalletBackupSnapshot(
    manifest: KeychainManifest(
      sourceFingerprint: base.manifest.sourceFingerprint,
      wallets: [
        ...base.manifest.wallets,
        BackupWallet(
          reference: 'vault-source',
          network: vault.record.recoveryPackage.policy.network,
          publicDescriptor: vault.record.recoveryPackage.policy.descriptor,
          signers: [],
          isDefault: false,
          isHidden: false,
          label: 'Heir vault',
        ),
      ],
      derivations: base.manifest.derivations,
      nostrKeys: base.manifest.nostrKeys,
      backupIdentities: base.manifest.backupIdentities,
    ),
    metadata: base.metadata,
    vaults: [
      BullVaultBackupEntry(
        reference: 'vault-source',
        status: BullVaultLifecycleStatus.active,
        recoveryPackage: vault.record.recoveryPackage,
      ),
    ],
  );
  final ciphertext = WalletBackupCiphertext(List.filled(64, 1));
  final head = WalletBackupRemoteHead(
    generation: 1,
    etag: 'a' * 64,
    ciphertext: ciphertext,
  );
  late _Identity identity;
  late _Remote remote;
  late _Codec codec;
  late _Vaults vaults;
  late _State state;
  late RestoreBullVaultBackupUsecase restore;
  setUp(() {
    identity = _Identity();
    remote = _Remote();
    codec = _Codec();
    vaults = _Vaults();
    state = _State();
    when(
      () => identity.fromWords(backupFixtureWords),
    ).thenReturn(Ok(credential));
    when(() => identity.resolve()).thenAnswer((_) async => Ok(credential));
    when(() => remote.fetch(credential)).thenAnswer((_) async => Ok(head));
    when(() => codec.decrypt(ciphertext, credential)).thenReturn(Ok(snapshot));
    when(
      () => vaults.restore(
        snapshot.vaults,
        snapshot.manifest.wallets,
        abandoned: any(named: 'abandoned'),
      ),
    ).thenAnswer((_) async {
      expect(state.incomplete, isTrue);
      return Ok(
        WalletInventoryRecovery(
          walletReferences: {'vault-source': 'actual-vault'},
          failedReferences: [],
        ),
      );
    });
    restore = RestoreBullVaultBackupUsecase(
      repository: vaults,
      state: state,
      operations: WalletBackupOperationQueue(),
      inspect: InspectWalletBackupUsecase(
        identity: identity,
        remote: remote,
        codec: codec,
      ),
    );
  });
  test(
    'words recover only vaults from one fetch without a local identity or a full-data acknowledgement',
    () async {
      final result = await restore.execute(words: backupFixtureWords);
      result.fold((value) {
        expect(value!.wallets.walletReferences, {
          'vault-source': 'actual-vault',
        });
        expect(value.inspection.snapshot, same(snapshot));
        expect(value.complete, isTrue);
      }, (failure) => fail('$failure'));
      verifyNever(identity.resolve);
      verify(() => remote.fetch(credential)).called(1);
      verifyNoMoreInteractions(remote);
      expect(state.writes, [true, false]);
      // The fake state throws for checkpoint, enablement and other mutations.
      // This use case has no ordinary-wallet, labels, settings or catalog writer.
    },
  );
  test(
    'a completed vault import cannot clear an earlier incomplete full-data recovery',
    () async {
      state.incomplete = true;
      final result = await restore.execute();
      expect(result, isA<Ok>());
      expect(state.incomplete, isTrue);
      expect(state.writes, [true]);
    },
  );
  test(
    'partial vault import retains actual results and the durable publication fence',
    () async {
      when(
        () => vaults.restore(
          snapshot.vaults,
          snapshot.manifest.wallets,
          abandoned: any(named: 'abandoned'),
        ),
      ).thenAnswer(
        (_) async => Ok(
          WalletInventoryRecovery(
            walletReferences: {},
            failedReferences: ['vault-source'],
          ),
        ),
      );
      final result = await restore.execute(words: backupFixtureWords);
      result.fold(
        (value) => expect(value!.complete, isFalse),
        (failure) => fail('$failure'),
      );
      expect(state.writes, [true]);
    },
  );
  test('leaving during fetch prevents all imports and state writes', () async {
    var abandoned = false;
    final pending =
        Completer<Result<WalletBackupRemoteHead, WalletBackupFailure>>();
    when(() => remote.fetch(credential)).thenAnswer((_) => pending.future);
    final running = restore.execute(
      words: backupFixtureWords,
      abandoned: () => abandoned,
    );
    await Future<void>.delayed(Duration.zero);
    abandoned = true;
    pending.complete(Ok(head));
    (await running).fold(
      (value) => expect(value, isNull),
      (failure) => fail('$failure'),
    );
    verifyZeroInteractions(vaults);
    expect(state.writes, isEmpty);
  });
  test('missing local credential fails before network or writes', () async {
    when(
      identity.resolve,
    ).thenAnswer((_) async => const Err(BackupCredentialUnavailable()));
    expect(await restore.execute(), isA<Err>());
    verifyZeroInteractions(remote);
    verifyZeroInteractions(vaults);
    expect(state.writes, isEmpty);
  });
}
