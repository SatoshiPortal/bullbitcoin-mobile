import 'dart:async';

import 'package:bb_mobile/core/utils/clock.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_backup_state.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_backup_wallet.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_remote_backup.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_backup_state_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/flush_keychain_manifest_backup_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/sync_keychain_manifest_backup_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late _StateRepository state;
  late _WalletPort wallet;
  late _SyncUsecase sync;
  late FlushKeychainManifestBackupUsecase usecase;

  setUp(() {
    state = _StateRepository();
    wallet = _WalletPort();
    sync = _SyncUsecase();
    usecase = FlushKeychainManifestBackupUsecase(
      state: state,
      wallet: wallet,
      sync: sync,
      clock: const _FixedClock(),
    );
    when(state.get).thenAnswer((_) async => _dirtyState);
    when(() => state.recordAttempt(any())).thenAnswer((_) async {});
    when(wallet.deriveDefaultWallet).thenAnswer((_) async => _backupWallet);
    when(
      () => sync.execute(
        parentFingerprint: any(named: 'parentFingerprint'),
        xprvBase58: any(named: 'xprvBase58'),
        now: any(named: 'now'),
      ),
    ).thenAnswer((_) async => _syncResult);
    when(
      () => state.recordSuccess(
        capturedDirtyRevision: any(named: 'capturedDirtyRevision'),
        succeededAt: any(named: 'succeededAt'),
        checkpoint: any(named: 'checkpoint'),
        contentHash: any(named: 'contentHash'),
      ),
    ).thenAnswer((_) async {});
  });

  setUpAll(() {
    registerFallbackValue(_checkpoint);
    registerFallbackValue(
      DateTime.fromMillisecondsSinceEpoch(10000, isUtc: true),
    );
  });

  test('clears only the dirty revision captured before upload', () async {
    await usecase.execute();

    verify(
      () => state.recordSuccess(
        capturedDirtyRevision: 7,
        succeededAt: 10,
        checkpoint: _checkpoint,
        contentHash: 'content-hash',
      ),
    ).called(1);
  });

  test('disabled backups do not derive keys or contact Bullnym', () async {
    when(
      state.get,
    ).thenAnswer((_) async => _dirtyState.copyWith(enabled: false));

    await usecase.execute();

    verifyNever(wallet.deriveDefaultWallet);
    verifyNever(
      () => sync.execute(
        parentFingerprint: any(named: 'parentFingerprint'),
        xprvBase58: any(named: 'xprvBase58'),
        now: any(named: 'now'),
      ),
    );
  });

  test('a trigger during upload schedules a trailing flush', () async {
    var stateReads = 0;
    when(state.get).thenAnswer((_) async {
      stateReads += 1;
      return _dirtyState.copyWith(dirtyRevision: stateReads == 1 ? 7 : 8);
    });
    final firstSync = Completer<KeychainManifestBackupSyncResult>();
    final firstStarted = Completer<void>();
    var syncCalls = 0;
    when(
      () => sync.execute(
        parentFingerprint: any(named: 'parentFingerprint'),
        xprvBase58: any(named: 'xprvBase58'),
        now: any(named: 'now'),
      ),
    ).thenAnswer((_) {
      syncCalls += 1;
      if (syncCalls == 1) {
        firstStarted.complete();
        return firstSync.future;
      }
      return Future.value(_syncResult);
    });

    final first = usecase.execute();
    await firstStarted.future;
    final trailing = usecase.execute();
    firstSync.complete(_syncResult);
    await Future.wait([first, trailing]);

    verify(
      () => sync.execute(
        parentFingerprint: any(named: 'parentFingerprint'),
        xprvBase58: any(named: 'xprvBase58'),
        now: any(named: 'now'),
      ),
    ).called(2);
  });

  test('an enabled empty inventory remains pending without failing', () async {
    when(
      () => sync.execute(
        parentFingerprint: any(named: 'parentFingerprint'),
        xprvBase58: any(named: 'xprvBase58'),
        now: any(named: 'now'),
      ),
    ).thenThrow(KeychainManifestEmptyInventoryException());

    await expectLater(usecase.execute(), completes);
    verifyNever(
      () => state.recordSuccess(
        capturedDirtyRevision: any(named: 'capturedDirtyRevision'),
        succeededAt: any(named: 'succeededAt'),
        checkpoint: any(named: 'checkpoint'),
        contentHash: any(named: 'contentHash'),
      ),
    );
  });
}

const _checkpoint = KeychainManifestRemoteCheckpoint(
  generation: 3,
  etag: 'etag',
);
const _syncResult = KeychainManifestBackupSyncResult(
  checkpoint: _checkpoint,
  contentHash: 'content-hash',
);
const _backupWallet = KeychainManifestBackupWallet(
  xprvBase58: 'xprv',
  parentFingerprint: 'fedcba98',
);
const _dirtyState = KeychainManifestBackupState(
  enabled: true,
  dirty: true,
  dirtyRevision: 7,
  lastAttemptedAt: null,
  lastSucceededAt: null,
  remoteGeneration: 0,
  remoteEtag: null,
  contentHash: null,
  unsupportedVersion: null,
);

extension on KeychainManifestBackupState {
  KeychainManifestBackupState copyWith({bool? enabled, int? dirtyRevision}) =>
      KeychainManifestBackupState(
        enabled: enabled ?? this.enabled,
        dirty: dirty,
        dirtyRevision: dirtyRevision ?? this.dirtyRevision,
        lastAttemptedAt: lastAttemptedAt,
        lastSucceededAt: lastSucceededAt,
        remoteGeneration: remoteGeneration,
        remoteEtag: remoteEtag,
        contentHash: contentHash,
        unsupportedVersion: unsupportedVersion,
      );
}

final class _StateRepository extends Mock
    implements KeychainManifestBackupStateRepository {}

final class _WalletPort extends Mock
    implements KeychainManifestBackupWalletPort {}

final class _SyncUsecase extends Mock
    implements SyncKeychainManifestBackupUsecase {}

final class _FixedClock implements Clock {
  const _FixedClock();

  @override
  DateTime nowUtc() => DateTime.fromMillisecondsSinceEpoch(10000, isUtc: true);
}
