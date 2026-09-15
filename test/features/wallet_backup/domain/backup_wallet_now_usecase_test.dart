import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/backup_wallet_now_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

final class _StateRepository extends Mock
    implements WalletBackupStateRepository {}

final _checkpoint = WalletBackupRemoteCheckpoint(
  generation: 3,
  etag: 'a' * 64,
  ciphertextSha256: 'b' * 64,
);

void main() {
  late _StateRepository state;

  setUpAll(() => registerFallbackValue(_checkpoint));

  setUp(() {
    state = _StateRepository();
    when(() => state.get()).thenAnswer((_) async => Ok(_dirtyState()));
  });

  test('a failed remote attempt never acknowledges the revision', () async {
    final usecase = BackupWalletNowUsecase(
      state: state,
      publish: (_) async => const Err(WalletBackupRemoteUnavailableFailure()),
      nowSecs: () => 100,
    );

    expect(
      await usecase.execute(),
      isA<Err<void, WalletBackupFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<WalletBackupRemoteUnavailableFailure>(),
      ),
    );
    verifyNever(
      () => state.recordPublication(
        publishedRevision: any(named: 'publishedRevision'),
        succeededAt: any(named: 'succeededAt'),
        checkpoint: any(named: 'checkpoint'),
      ),
    );
  });

  test('records the acknowledged head only after publication '
      'succeeds', () async {
    when(
      () => state.recordPublication(
        publishedRevision: 7,
        succeededAt: 100,
        checkpoint: _checkpoint,
      ),
    ).thenAnswer((_) async => const Ok(null));
    WalletBackupRemoteCheckpoint? publishedAgainst;
    final usecase = BackupWalletNowUsecase(
      state: state,
      publish: (checkpoint) async {
        publishedAgainst = checkpoint;
        return Ok(_checkpoint);
      },
      nowSecs: () => 100,
    );

    expect(await usecase.execute(), const Ok<void, WalletBackupFailure>(null));
    expect(publishedAgainst, same(_stored));
    verify(
      () => state.recordPublication(
        publishedRevision: 7,
        succeededAt: 100,
        checkpoint: _checkpoint,
      ),
    ).called(1);
  });

  test('nothing new to send is not a publication', () async {
    when(() => state.get()).thenAnswer((_) async => Ok(_cleanState()));
    var published = false;
    final usecase = BackupWalletNowUsecase(
      state: state,
      publish: (_) async {
        published = true;
        return Ok(_checkpoint);
      },
      nowSecs: () => 100,
    );

    expect(await usecase.execute(), const Ok<void, WalletBackupFailure>(null));
    expect(published, isFalse, reason: 'a clean state stores nothing');
    verifyNever(
      () => state.recordPublication(
        publishedRevision: any(named: 'publishedRevision'),
        succeededAt: any(named: 'succeededAt'),
        checkpoint: any(named: 'checkpoint'),
      ),
    );
  });

  test(
    'a raised recovery fence stops the pass before any remote call',
    () async {
      when(() => state.get()).thenAnswer(
        (_) async => Ok(
          _dirtyState(recoveryState: WalletBackupRecoveryState.needsAttention),
        ),
      );
      var synchronized = false;
      final usecase = BackupWalletNowUsecase(
        state: state,
        publish: (_) async {
          synchronized = true;
          return Ok(_checkpoint);
        },
        nowSecs: () => 100,
      );

      expect(
        await usecase.execute(),
        isA<Err<void, WalletBackupFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<WalletBackupRecoveryBlockedFailure>(),
        ),
      );
      expect(synchronized, isFalse);
    },
  );
}

WalletBackupState _dirtyState({
  WalletBackupRecoveryState recoveryState = WalletBackupRecoveryState.idle,
}) => WalletBackupState(
  enabled: true,
  localRevision: 7,
  uploadedRevision: 6,
  lastSucceededAt: null,
  unsupportedVersion: null,
  recoveryState: recoveryState,
  customServerUrl: null,
  remoteCheckpoint: _stored,
);

/// Everything local is already on the server: the revisions agree.
WalletBackupState _cleanState() => WalletBackupState(
  enabled: true,
  localRevision: 7,
  uploadedRevision: 7,
  lastSucceededAt: 90,
  unsupportedVersion: null,
  recoveryState: WalletBackupRecoveryState.idle,
  customServerUrl: null,
  remoteCheckpoint: _stored,
);

final _stored = WalletBackupRemoteCheckpoint(
  generation: 2,
  etag: 'c' * 64,
  ciphertextSha256: 'd' * 64,
);
