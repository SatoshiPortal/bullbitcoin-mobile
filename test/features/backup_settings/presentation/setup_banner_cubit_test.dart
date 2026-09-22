import 'dart:async';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/update_data_backup_lifecycle_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_setup_cubit.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Lifecycle extends Mock implements UpdateDataBackupLifecycleUsecase {}

void main() {
  late _Lifecycle lifecycle;
  late DataBackupSetupCubit cubit;
  setUp(() {
    lifecycle = _Lifecycle();
    when(
      () => lifecycle.execute(
        ready: any(named: 'ready'),
        foreground: any(named: 'foreground'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    cubit = DataBackupSetupCubit(lifecycle);
  });
  tearDown(() => cubit.close());
  test(
    'a failed setup remains visible and retry uses the same lifecycle owner',
    () async {
      when(
        () => lifecycle.execute(ready: true, foreground: true),
      ).thenAnswer((_) async => const Err(BackupSettingsUnexpectedFailure()));
      await cubit.update(ready: true, foreground: true);
      expect(cubit.state.failure, isA<BackupSettingsUnexpectedFailure>());
      when(
        () => lifecycle.execute(ready: true, foreground: true),
      ).thenAnswer((_) async => const Ok(WalletBackupControl(enabled: true)));
      await cubit.retry();
      expect(cubit.state.failure, isNull);
      expect(cubit.state.loading, isFalse);
      verify(() => lifecycle.execute(ready: true, foreground: true)).called(2);
    },
  );
  test(
    'durable incomplete recovery is visible even while backup is off',
    () async {
      when(() => lifecycle.execute(ready: true, foreground: true)).thenAnswer(
        (_) async => const Ok(
          WalletBackupControl(enabled: false, recoveryIncomplete: true),
        ),
      );
      await cubit.update(ready: true, foreground: true);
      expect(cubit.state.control!.recoveryIncomplete, isTrue);
    },
  );
  test(
    'backgrounding hides progress and a stale completion cannot replace it',
    () async {
      final pending =
          Completer<Result<WalletBackupControl?, BackupSettingsFailure>>();
      when(
        () => lifecycle.execute(ready: true, foreground: true),
      ).thenAnswer((_) => pending.future);
      final applying = cubit.update(ready: true, foreground: true);
      expect(cubit.state.loading, isTrue);
      await cubit.update(ready: true, foreground: false);
      pending.complete(const Err(BackupSettingsUnexpectedFailure()));
      await applying;
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.failure, isNull);
      expect(cubit.state.control, isNull);
    },
  );
}
