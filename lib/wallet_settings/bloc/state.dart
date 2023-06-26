import 'package:bb_mobile/_model/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
class WalletSettingsState with _$WalletSettingsState {
  const factory WalletSettingsState({
    required Wallet wallet,
    @Default('') String name,
    required List<String> mnemonic,
    @Default('') String password,
    @Default([]) List<String> shuffledMnemonic,
    @Default([]) List<({String word, int shuffleIdx})> testMnemonicOrder,
    @Default(false) bool backup,
    @Default('') String testBackupPassword,
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
  }) = _WalletSettingsState;
  const WalletSettingsState._();

  (String word, bool isSelected, int actualIdx) shuffleElementAt(int shuffleIdx) {
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
    final sameWordList = testMnemonicOrder.where((w) => w.word == word).toList();
    if (!_isSelected(shuffleIdx)) return mnemonic.indexOf(word, sameWordList.length);
    final position = sameWordList.indexWhere((w) => w.shuffleIdx == shuffleIdx);
    return mnemonic.indexOf(word, position);
  }

  bool _isSelected(int shuffleIdx) {
    return testMnemonicOrder.where((w) => w.shuffleIdx == shuffleIdx).isNotEmpty;
  }

  String testMneString() {
    return testMnemonicOrder.map((w) => w.word).join(' ');
  }
}


// final word = shuffledMnemonic[shuffleIdx];
// final wordCount = mnemonic.where((w) => w == word).length;
// final wordInTestMneCount = testMnemonicOrder.where((w) => w.$1 == word).length;
// if (wordCount == wordInTestMneCount) return true;
// return false;

// final isSelected = testMnemonicOrder.contains(word);
// final actualIdx = mnemonic.indexOf(word);

// String elementAt(int index) {
//   return mnemonic[index];
// }

// extension Helpers on List<String> {
//   bool hasRepeatedWord(String word) {
//     final count = where((w) => w == word).length;
//     return count > 1;
//   }
// }
