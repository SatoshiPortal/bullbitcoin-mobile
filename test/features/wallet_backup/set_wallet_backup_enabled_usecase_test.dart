import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/set_wallet_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

final class _StateRepository extends Mock
    implements WalletBackupStateRepository {}

void main() {
  late _StateRepository state;
  late Future<Result<void, WalletBackupFailure>> Function() register;
  late List<String> calls;

  setUp(() {
    state = _StateRepository();
    calls = [];
    register = () async {
      calls.add('register');
      return const Ok(null);
    };
  });

  test('recovers before enabling and publishing', () async {
    when(() => state.setEnabled(true)).thenAnswer((_) async {
      calls.add('enable');
      return const Ok(null);
    });
    final usecase = SetWalletBackupEnabledUsecase(
      state,
      () async {
        calls.add('recover');
        return const WalletBackupRecoveryResult(
          status: WalletBackupRecoveryStatus.noBackup,
        );
      },
      register,
      () async {
        calls.add('publish');
        return const Ok(null);
      },
    );

    expect(
      await usecase.execute(true),
      const Ok<void, WalletBackupFailure>(null),
    );
    expect(calls, ['register', 'recover', 'enable', 'publish']);
  });

  test('does not enable or publish when recovery fails', () async {
    final usecase = SetWalletBackupEnabledUsecase(
      state,
      () async {
        calls.add('recover');
        return const WalletBackupRecoveryResult(
          status: WalletBackupRecoveryStatus.invalid,
        );
      },
      register,
      () async {
        calls.add('publish');
        return const Ok(null);
      },
    );

    final result = await usecase.execute(true);

    expect(
      result,
      isA<Err<void, WalletBackupFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<WalletBackupManifestFailure>(),
      ),
    );
    expect(calls, ['register', 'recover']);
    verifyNever(() => state.setEnabled(true));
  });

  test('does not publish when enabling fails', () async {
    when(
      () => state.setEnabled(true),
    ).thenAnswer((_) async => const Err(WalletBackupStorageFailure()));
    final usecase = SetWalletBackupEnabledUsecase(
      state,
      () async => const WalletBackupRecoveryResult(
        status: WalletBackupRecoveryStatus.restored,
      ),
      register,
      () async {
        calls.add('publish');
        return const Ok(null);
      },
    );

    expect(
      await usecase.execute(true),
      isA<Err<void, WalletBackupFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<WalletBackupStorageFailure>(),
      ),
    );
    expect(calls, ['register']);
  });

  test('does not recover, enable or publish when registration fails', () async {
    register = () async => const Err(WalletBackupWalletUnavailableFailure());
    final usecase = SetWalletBackupEnabledUsecase(
      state,
      () async {
        calls.add('recover');
        return const WalletBackupRecoveryResult(
          status: WalletBackupRecoveryStatus.noBackup,
        );
      },
      register,
      () async {
        calls.add('publish');
        return const Ok(null);
      },
    );

    expect(
      await usecase.execute(true),
      isA<Err<void, WalletBackupFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<WalletBackupWalletUnavailableFailure>(),
      ),
    );
    expect(calls, isEmpty);
    verifyNever(() => state.setEnabled(true));
  });
}
