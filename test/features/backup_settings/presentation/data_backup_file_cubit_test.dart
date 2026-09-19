import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_inventory_recovery.dart';
import 'dart:async';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_data_backup_files_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_file_cubit.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../vault_recovery_fixture.dart';

class _Export extends Mock implements ExportDataBackupFileUsecase {}

class _Inspect extends Mock implements InspectDataBackupFileUsecase {}

class _Recover extends Mock implements RecoverDataBackupFileUsecase {}

void main() {
  late _Export exporter;
  late _Inspect inspect;
  late _Recover recover;
  late DataBackupFileCubit cubit;
  late WalletBackupFileComparison comparison;
  setUp(() {
    exporter = _Export();
    inspect = _Inspect();
    recover = _Recover();
    cubit = DataBackupFileCubit(exporter, inspect, recover);
    comparison = WalletBackupFileComparison(
      file: WalletBackupFile(
        format: WalletBackupFileFormat.readable,
        snapshot: vaultRecoveryFixture().inspection.snapshot!,
        createdAt: DateTime.utc(2026, 9, 19),
      ),
      server: null,
      automaticBackupEnabled: false,
      serverFailure: const WalletBackupNetworkFailure(),
    );
    when(inspect.execute).thenAnswer(
      (_) async => Ok((source: 'validated file', comparison: comparison)),
    );
  });
  tearDown(() => cubit.close());
  test(
    'comparison requires an explicit selected source; cancellation does not recover',
    () async {
      await cubit.inspect();
      expect(cubit.state.comparison, same(comparison));
      verifyZeroInteractions(recover);
      await cubit.recover(WalletBackupImportSource.file, confirmed: false);
      verifyZeroInteractions(recover);
    },
  );
  test(
    'partial application stays visible and can retry the same selected file',
    () async {
      final partial = WalletBackupRecovery(
        wallets: WalletInventoryRecovery(
          walletReferences: {},
          failedReferences: ['source-vault'],
        ),
        publicRecordsRestored: false,
        metadataRestored: false,
      );
      when(
        () => recover.execute(
          'validated file',
          comparison: comparison,
          source: WalletBackupImportSource.file,
          confirmed: true,
        ),
      ).thenAnswer((_) async => Ok(partial));
      await cubit.inspect();
      await cubit.recover(WalletBackupImportSource.file, confirmed: true);
      expect(cubit.state.result!.complete, isFalse);
      expect(
        cubit.state.failure,
        isA<BackupSettingsRecoveryIncompleteFailure>(),
      );
      await cubit.recover(WalletBackupImportSource.file, confirmed: true);
      verify(
        () => recover.execute(
          'validated file',
          comparison: comparison,
          source: WalletBackupImportSource.file,
          confirmed: true,
        ),
      ).called(2);
    },
  );
  test('cancel clears the file so a later recovery cannot apply it', () async {
    await cubit.inspect();
    cubit.reset();
    await cubit.recover(WalletBackupImportSource.file, confirmed: true);
    verifyZeroInteractions(recover);
    expect(cubit.state.comparison, isNull);
  });
  test('late inspection cannot repopulate a cancelled selection', () async {
    final pending =
        Completer<
          Result<
            ({String source, WalletBackupFileComparison comparison})?,
            BackupSettingsFailure
          >
        >();
    when(inspect.execute).thenAnswer((_) => pending.future);
    final selecting = cubit.inspect();
    cubit.reset();
    pending.complete(Ok((source: 'validated file', comparison: comparison)));
    await selecting;
    expect(cubit.state.comparison, isNull);
    await cubit.recover(WalletBackupImportSource.file, confirmed: true);
    verifyZeroInteractions(recover);
  });
  test('cancelled export leaves no success message', () async {
    when(
      () =>
          exporter.execute(WalletBackupFileFormat.encrypted, confirmed: false),
    ).thenAnswer((_) async => const Ok(false));
    await cubit.export(WalletBackupFileFormat.encrypted);
    expect(cubit.state.exported, isFalse);
    expect(cubit.state.busy, isFalse);
  });
}
