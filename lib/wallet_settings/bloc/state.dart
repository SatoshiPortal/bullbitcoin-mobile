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
    @Default([]) List<String> testMnemonicOrder,
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

  String elementAt(int index) {
    return mnemonic[index];
  }

  (String, bool, int) shuffleElementAt(int index) {
    final word = shuffledMnemonic[index];
    final isSelected = testMnemonicOrder.contains(word);
    final actualIdx = mnemonic.indexOf(word);
    return (word, isSelected, actualIdx);
  }
}
