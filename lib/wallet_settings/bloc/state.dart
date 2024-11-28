import 'package:bb_mobile/_model/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
class WalletSettingsState with _$WalletSettingsState {
  const factory WalletSettingsState({
    required Wallet wallet,
    @Default('') String name,
    /**
     * 
     * SENSITIVE
     * 
     */
    @Default([]) List<String> mnemonic,
    @Default('') String password,
    @Default([]) List<String> shuffledMnemonic,
    @Default([])
    List<({String word, int shuffleIdx, int selectedActualIdx})>
        testMnemonicOrder,
    @Default('') String testBackupPassword,
    /**
     * 
     * SENSITIVE
     * 
     */
    @Default(false) bool backup,
    @Default(false) bool testingBackup,
    @Default('') String errTestingBackup,
    @Default(false) bool backupTested,
    @Default(false) bool gettingAddresses,
    @Default('') String errGettingAddresses,
    @Default(false) bool savingName,
    @Default('') String errSavingName,
    @Default(false) bool savedName,
    @Default(false) bool deleting,
    @Default('') String errDeleting,
    @Default(false) bool deleted,
    @Default(false) bool savingFile,
    @Default('') String errSavingFile,
    @Default(false) bool savedFile,
    @Default('') String errImporting,
    @Default(false) bool importing,
    @Default(false) bool imported,
    @Default('') String errExporting,
    @Default(false) bool exporting,
    @Default(false) bool exported,
  }) = _WalletSettingsState;
  const WalletSettingsState._();

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

  bool _isSelected(int shuffleIdx) =>
      testMnemonicOrder.where((w) => w.shuffleIdx == shuffleIdx).isNotEmpty;

  String testMneString() => testMnemonicOrder.map((w) => w.word).join(' ');
}
