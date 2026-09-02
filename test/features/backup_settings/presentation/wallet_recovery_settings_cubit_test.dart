import 'dart:async';

import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_wallet_recovery_status_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/wallet_recovery_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'uses the active Bitcoin wallet test timestamps as recovery truth',
    () async {
      final physical = DateTime.utc(2026, 1, 2);
      final encrypted = DateTime.utc(2026, 2, 3);
      final cubit = WalletRecoverySettingsCubit(
        GetWalletRecoveryStatusUsecase(
          () async => Environment.testnet,
          (_) async => [
            (latestPhysicalBackup: physical, latestEncryptedBackup: encrypted),
          ],
        ),
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.hasPhysicalBackup, isTrue);
      expect(cubit.state.hasEncryptedBackup, isTrue);
      expect(cubit.state.lastPhysicalBackup, physical);
      expect(cubit.state.lastEncryptedBackup, encrypted);
    },
  );

  test('does not emit when wallet loading finishes after close', () async {
    final statuses = Completer<List<WalletBackupTestStatus>>();
    final cubit = WalletRecoverySettingsCubit(
      GetWalletRecoveryStatusUsecase(
        () async => Environment.mainnet,
        (_) => statuses.future,
      ),
    );

    final pending = cubit.load();
    await cubit.close();
    statuses.complete([
      (latestPhysicalBackup: null, latestEncryptedBackup: null),
    ]);
    await pending;

    expect(cubit.state.loaded, isFalse);
  });
}
