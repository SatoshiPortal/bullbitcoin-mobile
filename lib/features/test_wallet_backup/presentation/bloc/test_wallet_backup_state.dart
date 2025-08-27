part of 'test_wallet_backup_bloc.dart';

enum TestWalletBackupStatus { none, loading, verifying, success, error }

enum TestPhysicalBackupFlow { none, error }

// Make this a regular class instead of a mixin
class TestWalletBackupStateMethods {
  final List<String> shuffledMnemonic;
  final List<String> mnemonic;
  final List<({String word, int shuffleIdx, int selectedActualIdx})>
  testMnemonicOrder;

  TestWalletBackupStateMethods({
    required this.shuffledMnemonic,
    required this.mnemonic,
    required this.testMnemonicOrder,
  });

  (String word, bool isSelected, int actualIdx) shuffleElementAt(
    int shuffleIdx,
  ) {
    try {
      final word = shuffledMnemonic[shuffleIdx];
      final isSelected = _isSelected(shuffleIdx);
      final actualIdx = _actualIdx(shuffleIdx);
      return (word, isSelected, actualIdx);
    } catch (e) {
      return ('', false, 0);
    }
  }

  bool _isSelected(int shuffleIdx) =>
      testMnemonicOrder.where((w) => w.shuffleIdx == shuffleIdx).isNotEmpty;

  int _actualIdx(int shuffleIdx) {
    final word = shuffledMnemonic[shuffleIdx];
    final wordCount = mnemonic.where((w) => w == word).length;

    if (wordCount == 1) return mnemonic.indexOf(word);
    if (_isSelected(shuffleIdx)) {
      return testMnemonicOrder
          .firstWhere((w) => w.shuffleIdx == shuffleIdx)
          .selectedActualIdx;
    }
    return mnemonic.indexOf(word, testMnemonicOrder.length - 1);
  }

  String testMnemonic() => testMnemonicOrder.map((w) => w.word).join(' ');
}

@freezed
abstract class TestWalletBackupState with _$TestWalletBackupState {
  const factory TestWalletBackupState({
    @Default([]) List<Wallet> wallets,
    Wallet? selectedWallet,
    @Default([]) List<String> mnemonic,
    @Default([]) List<String> shuffledMnemonic,
    @Default([])
    List<({String word, int shuffleIdx, int selectedActualIdx})>
    testMnemonicOrder,
    @Default('') String passphrase,
    @Default(TestWalletBackupStatus.none) TestWalletBackupStatus status,
    @Default(VaultProvider.googleDrive()) VaultProvider vaultProvider,
    @Default(BackupInfo.empty()) BackupInfo selectedBackup,
    @Default(<DriveFile>[]) List<DriveFile> availableCloudBackups,
    @Default(false) bool transitioning,

    @Default('') String statusError,
  }) = _TestWalletBackupState;
  const TestWalletBackupState._();

  // Implement the methods here using the helper class
  (String word, bool isSelected, int actualIdx) shuffleElementAt(
    int shuffleIdx,
  ) {
    return TestWalletBackupStateMethods(
      shuffledMnemonic: shuffledMnemonic,
      mnemonic: mnemonic,
      testMnemonicOrder: testMnemonicOrder,
    ).shuffleElementAt(shuffleIdx);
  }
}
