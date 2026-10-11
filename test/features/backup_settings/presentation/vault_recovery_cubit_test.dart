import 'dart:async';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vaults_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_recovery_cubit.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../vault_recovery_fixture.dart';

class _Backups extends Mock implements WalletBackupFacade {}

void main() {
  late _Backups backups;
  late VaultRecoveryCubit cubit;
  setUp(() {
    backups = _Backups();
    cubit = VaultRecoveryCubit(RecoverVaultsUsecase(backups));
  });
  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
  });
  test(
    'words entry calls only vault recovery and preserves partial results',
    () async {
      final report = vaultRecoveryFixture(partial: true);
      when(
        () => backups.recoverVaults(
          words: 'words',
          abandoned: any(named: 'abandoned'),
        ),
      ).thenAnswer((_) async => Ok(report));
      await cubit.search(words: 'words');
      expect(cubit.state.result, same(report));
      expect(cubit.state.result!.complete, isFalse);
      expect(cubit.state.busy, isFalse);
      verify(
        () => backups.recoverVaults(
          words: 'words',
          abandoned: any(named: 'abandoned'),
        ),
      ).called(1);
      verifyNoMoreInteractions(backups);
    },
  );
  test(
    'missing local credential is a visible failure and retry clears it',
    () async {
      when(
        () => backups.recoverVaults(
          words: null,
          abandoned: any(named: 'abandoned'),
        ),
      ).thenAnswer((_) async => const Err(WalletBackupCredentialFailure()));
      await cubit.search();
      expect(cubit.state.failure, isA<BackupSettingsWordsUnavailableFailure>());
      final report = vaultRecoveryFixture();
      when(
        () => backups.recoverVaults(
          words: null,
          abandoned: any(named: 'abandoned'),
        ),
      ).thenAnswer((_) async => Ok(report));
      await cubit.search();
      expect(cubit.state.failure, isNull);
      expect(cubit.state.result!.complete, isTrue);
    },
  );
  test(
    'closing the journey cancels later imports and duplicate search is ignored',
    () async {
      final pending =
          Completer<Result<VaultBackupRecovery?, WalletBackupFailure>>();
      late bool Function() abandoned;
      when(
        () => backups.recoverVaults(
          words: 'words',
          abandoned: any(named: 'abandoned'),
        ),
      ).thenAnswer((call) {
        abandoned = call.namedArguments[#abandoned] as bool Function();
        return pending.future;
      });
      final running = cubit.search(words: 'words');
      await cubit.search(words: 'words');
      expect(abandoned(), isFalse);
      await cubit.close();
      expect(abandoned(), isTrue);
      pending.complete(Ok(vaultRecoveryFixture()));
      await running;
      verify(
        () => backups.recoverVaults(
          words: 'words',
          abandoned: any(named: 'abandoned'),
        ),
      ).called(1);
    },
  );
}
