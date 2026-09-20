import 'dart:async';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/data_backup_status.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_data_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_settings_cubit.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Load extends Mock implements LoadDataBackupStatusUsecase {}

class _Watch extends Mock implements WatchDataBackupStatusUsecase {}

class _Set extends Mock implements SetDataBackupEnabledUsecase {}

class _Publish extends Mock implements PublishDataBackupUsecase {}

class _Delete extends Mock implements DeleteDataBackupUsecase {}

void main() {
  late _Load load;
  late _Watch watch;
  late _Set setEnabled;
  late _Publish publish;
  late _Delete delete;
  late DataBackupSettingsCubit cubit;
  late StreamController<void> changes;
  const on = DataBackupStatus(control: WalletBackupControl(enabled: true));
  const off = DataBackupStatus(control: WalletBackupControl(enabled: false));
  setUp(() {
    load = _Load();
    watch = _Watch();
    setEnabled = _Set();
    publish = _Publish();
    delete = _Delete();
    changes = StreamController<void>.broadcast(sync: true);
    when(load.execute).thenAnswer((_) async => const Ok(on));
    when(watch.execute).thenAnswer((_) => changes.stream);
    cubit = DataBackupSettingsCubit(load, watch, setEnabled, publish, delete);
  });
  tearDown(() async {
    await cubit.close();
    await changes.close();
  });

  test(
    'off interrupts a manual upload and its late success cannot undo off',
    () async {
      await cubit.start();
      final pending =
          Completer<Result<WalletBackupPublication, BackupSettingsFailure>>();
      when(() => publish.execute()).thenAnswer((_) => pending.future);
      when(() => setEnabled.execute(false)).thenAnswer((_) async {
        when(load.execute).thenAnswer((_) async => const Ok(off));
        return const Ok(null);
      });
      final uploading = cubit.publish();
      expect(cubit.state.working, isTrue);
      await cubit.setEnabled(false);
      expect(cubit.state.data!.control.enabled, isFalse);
      pending.complete(const Ok(WalletBackupPublication.published));
      await uploading;
      expect(cubit.state.data!.control.enabled, isFalse);
      expect(cubit.state.working, isFalse);
      verify(() => setEnabled.execute(false)).called(1);
    },
  );

  test(
    'owner events coalesce a pending read and never emit the outdated choice',
    () async {
      final pending =
          Completer<Result<DataBackupStatus, BackupSettingsFailure>>();
      when(load.execute).thenAnswer((_) => pending.future);
      final states = <DataBackupSettingsState>[];
      final subscription = cubit.stream.listen(states.add);
      final loading = cubit.start();
      changes.add(null);
      changes.add(null);
      when(load.execute).thenAnswer((_) async => const Ok(off));
      pending.complete(const Ok(on));
      await loading;
      await Future<void>.delayed(Duration.zero);
      expect(states.any((s) => s.data?.control.enabled == true), isFalse);
      expect(cubit.state.data!.control.enabled, isFalse);
      verify(load.execute).called(2);
      await subscription.cancel();
    },
  );

  test('a successful retry clears a prior status-read failure', () async {
    when(
      load.execute,
    ).thenAnswer((_) async => const Err(BackupSettingsUnexpectedFailure()));
    await cubit.start();
    expect(cubit.state.readFailure, isNotNull);
    when(load.execute).thenAnswer((_) async => const Ok(off));
    await cubit.refresh();
    expect(cubit.state.readFailure, isNull);
    expect(cubit.state.data!.control.enabled, isFalse);
  });

  test(
    'screen entry requests publication once, owner refreshes only read',
    () async {
      when(
        () => load.execute(retryPublication: true),
      ).thenAnswer((_) async => const Ok(on));
      await cubit.start(retryPublication: true);
      await cubit.refresh();
      verify(() => load.execute(retryPublication: true)).called(1);
      verify(load.execute).called(1);
    },
  );

  test(
    'retry intent survives an already pending read and clears action failure',
    () async {
      await cubit.start();
      when(
        () => publish.execute(),
      ).thenAnswer((_) async => const Err(BackupSettingsNetworkFailure()));
      await cubit.publish();
      expect(cubit.state.failure, isNotNull);
      final pending =
          Completer<Result<DataBackupStatus, BackupSettingsFailure>>();
      when(load.execute).thenAnswer((_) => pending.future);
      when(
        () => load.execute(retryPublication: true),
      ).thenAnswer((_) async => const Ok(on));
      final reading = cubit.refresh();
      await cubit.refresh(retryPublication: true);
      pending.complete(const Ok(on));
      await reading;
      expect(cubit.state.failure, isNull);
      verify(() => load.execute(retryPublication: true)).called(1);
    },
  );

  test('cancelled deletion never calls its use case', () async {
    await cubit.delete(confirmed: false);
    verifyZeroInteractions(delete);
  });

  test(
    'closing unsubscribes and a pending load cannot emit afterwards',
    () async {
      final pending =
          Completer<Result<DataBackupStatus, BackupSettingsFailure>>();
      when(load.execute).thenAnswer((_) => pending.future);
      final loading = cubit.start();
      await cubit.close();
      expect(changes.hasListener, isFalse);
      pending.complete(const Ok(on));
      await loading;
    },
  );
}
