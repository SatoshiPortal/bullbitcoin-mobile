import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_preferences_restore_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backup preferences may override defaults on a just-created wallet', () {
    expect(
      WalletPreferencesRestorePolicy.classify(
        walletExists: true,
        createdInRecovery: true,
      ),
      WalletPreferencesRestoreDisposition.applyToCreatedWallet,
    );
  });

  test('an existing wallet keeps local choices and reports conflict', () {
    expect(
      WalletPreferencesRestorePolicy.classify(
        walletExists: true,
        createdInRecovery: false,
      ),
      WalletPreferencesRestoreDisposition.conflictWithExistingWallet,
    );
  });

  test('a missing wallet defers even if recovery expected to create it', () {
    expect(
      WalletPreferencesRestorePolicy.classify(
        walletExists: false,
        createdInRecovery: true,
      ),
      WalletPreferencesRestoreDisposition.deferredMissingWallet,
    );
    expect(
      WalletPreferencesRestorePolicy.classify(
        walletExists: false,
        createdInRecovery: false,
      ),
      WalletPreferencesRestoreDisposition.deferredMissingWallet,
    );
  });
}
