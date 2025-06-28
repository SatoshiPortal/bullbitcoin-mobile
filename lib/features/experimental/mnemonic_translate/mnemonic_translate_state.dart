import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'mnemonic_translate_state.freezed.dart';

@freezed
abstract class MnemonicTranslateState with _$MnemonicTranslateState {
  const factory MnemonicTranslateState({
    @Default([]) List<String> defaultMnemonic,
    @Default([]) List<String> translatedMnemonic,
    @Default(null) String? passphrase,
    @Default(bip39.Language.values) List<bip39.Language> languages,
    @Default(bip39.Language.english) bip39.Language selectedLanguage,
    String? error,
  }) = _MnemonicTranslateState;

  factory MnemonicTranslateState.initial() => const MnemonicTranslateState();
}
