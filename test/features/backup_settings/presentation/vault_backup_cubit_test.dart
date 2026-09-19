import 'dart:async';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_vault_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_backup_status.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_backup_cubit.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../bullvault/bullvault_test_fixture.dart';

class _Load extends Mock implements LoadVaultBackupUsecase {}

class _Check extends Mock implements CheckVaultServerBackupUsecase {}

class _Verify extends Mock implements VerifyVaultDescriptorBackupUsecase {}

void main() {
  final record = testBullVaultCreateResult(walletId: 'selected').record;
  final data = VaultBackupStatus(
    record: record,
    recoveryPackageSource: 'fixture-package',
    control: const WalletBackupControl(enabled: true, recoveryIncomplete: true),
    canRevealWords: true,
  );
  final inspection = WalletBackupInspection(
    identity: 'a' * 64,
    head: WalletBackupRemoteHead(generation: 0, etag: null),
    snapshot: null,
  );
  final date = DateTime.utc(2026, 9, 18);
  late _Load load;
  late _Check check;
  late _Verify descriptor;
  late VaultBackupCubit cubit;
  setUp(() {
    load = _Load();
    check = _Check();
    descriptor = _Verify();
    when(() => load.execute('selected')).thenAnswer((_) async => Ok(data));
    cubit = VaultBackupCubit(load, check, descriptor);
  });
  tearDown(() => cubit.close());
  test(
    'successful server check updates this record without reload and keeps incomplete status',
    () async {
      when(() => check.execute(record)).thenAnswer(
        (_) async => Ok(
          VaultBackupCheck(record.copyWith(serverTestedAt: date), inspection),
        ),
      );
      await cubit.load('selected');
      clearInteractions(load);
      await cubit.checkServer();
      final state = cubit.state as VaultBackupLoaded;
      expect(state.data.record.serverTestedAt, date);
      expect(state.data.record.descriptorTestedAt, isNull);
      expect(state.data.control.recoveryIncomplete, isTrue);
      expect(state.inspection, same(inspection));
      expect(state.busy, isFalse);
      verifyNever(() => load.execute('selected'));
    },
  );
  test(
    'repeated taps do not duplicate a server action; failure retains the real dates',
    () async {
      final pending =
          Completer<Result<VaultBackupCheck, BackupSettingsFailure>>();
      when(() => check.execute(record)).thenAnswer((_) => pending.future);
      await cubit.load('selected');
      final running = cubit.checkServer();
      await cubit.checkServer();
      verify(() => check.execute(record)).called(1);
      pending.complete(const Err(BackupSettingsNetworkFailure()));
      await running;
      expect(
        (cubit.state as VaultBackupLoaded).failure,
        isA<BackupSettingsNetworkFailure>(),
      );
      expect(
        (cubit.state as VaultBackupLoaded).data.record.serverTestedAt,
        isNull,
      );
    },
  );
  test(
    'cancelled file and manual mismatch do not produce a descriptor date',
    () async {
      when(
        () => descriptor.execute(record),
      ).thenAnswer((_) async => const Ok(null));
      await cubit.load('selected');
      await cubit.verifyDescriptor();
      expect(
        (cubit.state as VaultBackupLoaded).data.record.descriptorTestedAt,
        isNull,
      );
      expect((cubit.state as VaultBackupLoaded).failure, isNull);
      when(() => descriptor.execute(record, source: 'wrong')).thenAnswer(
        (_) async => const Err(BackupSettingsVaultMismatchFailure()),
      );
      await cubit.verifyDescriptor('wrong');
      expect(
        (cubit.state as VaultBackupLoaded).failure,
        isA<BackupSettingsVaultMismatchFailure>(),
      );
      expect(
        (cubit.state as VaultBackupLoaded).data.record.descriptorTestedAt,
        isNull,
      );
    },
  );
  test('manual read-back updates only the descriptor date', () async {
    when(
      () => descriptor.execute(record, source: 'copy'),
    ).thenAnswer((_) async => Ok(date));
    await cubit.load('selected');
    await cubit.verifyDescriptor('copy');
    final state = cubit.state as VaultBackupLoaded;
    expect(state.data.record.descriptorTestedAt, date);
    expect(state.data.record.serverTestedAt, isNull);
    expect(state.data.record.recoveryPackageConfirmed, isFalse);
  });
  test('late action result cannot overwrite a newly selected vault', () async {
    final other = testBullVaultCreateResult(walletId: 'other').record;
    when(() => load.execute('other')).thenAnswer(
      (_) async => Ok(
        VaultBackupStatus(
          record: other,
          recoveryPackageSource: 'other-package',
          control: data.control,
          canRevealWords: false,
        ),
      ),
    );
    final pending =
        Completer<Result<VaultBackupCheck, BackupSettingsFailure>>();
    when(() => check.execute(record)).thenAnswer((_) => pending.future);
    await cubit.load('selected');
    final running = cubit.checkServer();
    await cubit.load('other');
    pending.complete(
      Ok(VaultBackupCheck(record.copyWith(serverTestedAt: date), inspection)),
    );
    await running;
    expect((cubit.state as VaultBackupLoaded).data.record.walletId, 'other');
    expect(
      (cubit.state as VaultBackupLoaded).data.record.serverTestedAt,
      isNull,
    );
  });
}
