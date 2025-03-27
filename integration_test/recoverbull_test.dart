import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';
import 'package:bb_mobile/backup_wallet/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/key_server/domain/usecases/derive_backup_key_from_default_wallet_usecase.dart';
import 'package:bb_mobile/key_server/domain/usecases/restore_backup_key_from_password_usecase.dart';
import 'package:bb_mobile/key_server/domain/usecases/store_backup_key_into_server_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/recover_wallet/domain/usecases/restore_encrypted_vault_from_backup_key_usecase.dart';
import 'package:bb_mobile/settings/domain/usecases/set_environment_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:test/test.dart';

void main() {
  late WalletManagerService walletManagerService;

  setUpAll(() async {
    await Future.wait([Hive.initFlutter()]);

    await AppLocator.setup();

    await locator<SetEnvironmentUsecase>().execute(Environment.mainnet);

    walletManagerService = locator<WalletManagerService>();
  });

  setUp(() async {
    // Sync the wallets before every other test
    await walletManagerService.syncAll();
    debugPrint('Wallets synced');
  });

  test('Encrypted Vault and Store the Backup Key Into the Server', () async {
    const password = 'PasswØrd';

    final backupFile = await locator<CreateEncryptedVaultUsecase>().execute();

    final backupKey = await locator<DeriveBackupKeyFromDefaultWalletUsecase>()
        .execute(backupFile: backupFile);

    await locator<StoreBackupKeyIntoServerUsecase>().execute(
      password: password,
      backupFile: backupFile,
      backupKey: backupKey,
    );

    await locator<RestoreBackupKeyFromPasswordUsecase>().execute(
      backupFile: backupFile,
      password: password,
    );

    await locator<RestoreEncryptedVaultFromBackupKeyUsecase>().execute(
      backupFile: backupFile,
      backupKey: backupKey,
    );

    // TODO: make TOR work with this test

    expect(true, true);
  });
}
