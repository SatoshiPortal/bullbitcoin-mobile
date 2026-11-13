import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/check_physical_backup_verified_usecase.dart';

export 'package:bb_mobile/features/test_wallet_backup/ui/screens/show_mnemonic_screen.dart'
    show ShowMnemonicScreen;
export 'package:bb_mobile/features/test_wallet_backup/ui/screens/verify_mnemonic_screen.dart'
    show VerifyMnemonicScreen;

enum TestPhysicalBackupFlow { backup, verify }

final class VerifyPhysicalBackupRequest {
  final String fingerprint;

  VerifyPhysicalBackupRequest({required this.fingerprint}) {
    if (fingerprint.isEmpty) {
      throw ArgumentError.value(fingerprint, 'fingerprint');
    }
  }
}

class TestWalletBackupFacade {
  static const routeName = 'testPhysicalBackupFlow';

  final CheckPhysicalBackupVerifiedUsecase _checkPhysicalBackupVerifiedUsecase;

  const TestWalletBackupFacade(this._checkPhysicalBackupVerifiedUsecase);

  Future<bool> isPhysicalBackupVerified(String fingerprint) =>
      _checkPhysicalBackupVerifiedUsecase.execute(fingerprint);
}
