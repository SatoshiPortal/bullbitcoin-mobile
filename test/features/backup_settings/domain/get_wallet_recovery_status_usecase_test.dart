import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_wallet_recovery_status_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show Err, Ok;

void main() {
  test('returns test dates without loading wallet balances', () async {
    final physical = DateTime.utc(2026, 1, 2);
    final encrypted = DateTime.utc(2026, 3, 4);
    final usecase = GetWalletRecoveryStatusUsecase(
      () async => Environment.mainnet,
      (environment) async {
        expect(environment, Environment.mainnet);
        return [
          (latestPhysicalBackup: physical, latestEncryptedBackup: encrypted),
        ];
      },
    );

    final result = await usecase.execute();

    expect(result, isA<Ok<WalletRecoveryStatus, BackupSettingsFailure>>());
    final value = (result as Ok).value as WalletRecoveryStatus;
    expect(value.lastPhysicalBackup, physical);
    expect(value.lastEncryptedBackup, encrypted);
  });

  test('returns a typed failure when metadata loading fails', () async {
    final usecase = GetWalletRecoveryStatusUsecase(
      () async => Environment.mainnet,
      (_) async => throw Exception('storage unavailable'),
    );

    final result = await usecase.execute();

    expect(result, isA<Err<WalletRecoveryStatus, BackupSettingsFailure>>());
    expect((result as Err).failure, isA<BackupSettingsUnexpectedFailure>());
  });
}
