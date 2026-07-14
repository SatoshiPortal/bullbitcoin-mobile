import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/recoverbull/domain/complete_encrypted_vault_backup_usecase.dart';
import 'package:get_it/get_it.dart';

class RecoverBullLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<CompleteEncryptedVaultBackupUsecase>(
      () => CompleteEncryptedVaultBackupUsecase(locator<WalletRepository>()),
    );
  }
}
