import 'package:bb_mobile/_model/wallet_sensitive_data.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
part 'backup_settings_state.freezed.dart';

@freezed
class BackupSettingsState with _$BackupSettingsState {
  const factory BackupSettingsState({
    // Verification properties
    @Default([]) List<String> mnemonic,
    @Default('') String password,
    @Default([]) List<String> shuffledMnemonic,
    @Default([])
    List<({String word, int shuffleIdx, int selectedActualIdx})>
        testMnemonicOrder,
    @Default('') String testBackupPassword,
    @Default(false) bool testingBackup,
    @Default('') String errTestingBackup,
    @Default(false) bool backupTested,
    @Default(false) bool loadingBackups,
    @Default([]) List<WalletSensitiveData> loadedBackups,
    @Default('') String errorLoadingBackups,
    @Default(false) bool savingBackups,
    @Default('') String errorSavingBackups,
    @Default('') String backupId,
    @Default('') String backupFolderPath,
    @Default('') String backupSalt,
    @Default('') String backupKey,
    @Default({}) Map<String, dynamic> latestRecoveredBackup,
    @Default(null) DateTime? lastBackupAttempt,
  }) = _BackupSettingsState;

  const BackupSettingsState._();

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

  String testMneString() => testMnemonicOrder.map((w) => w.word).join(' ');
}
