import 'package:bb_mobile/features/experimental/mnemonic_translate/domain/usecases/get_default_mnemonic_usecase.dart';
import 'package:bb_mobile/features/experimental/mnemonic_translate/mnemonic_translate_state.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_bloc/flutter_bloc.dart';

class MnemonicTranslateCubit extends Cubit<MnemonicTranslateState> {
  final GetDefaultMnemonicUsecase _getDefaultMnemonicUsecase;

  MnemonicTranslateCubit({
    required GetDefaultMnemonicUsecase getDefaultMnemonicUsecase,
  }) : _getDefaultMnemonicUsecase = getDefaultMnemonicUsecase,
       super(const MnemonicTranslateState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final (mnemonic, passphrase) = await _getDefaultMnemonicUsecase.execute();
      emit(state.copyWith(defaultMnemonic: mnemonic, passphrase: passphrase));
      translate();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void translate() {
    try {
      final defaultMnemonic = bip39.Mnemonic.fromWords(
        words: state.defaultMnemonic,
      );

      final translatedMnemonic = bip39.Mnemonic(
        defaultMnemonic.entropy,
        state.selectedLanguage,
      );

      emit(
        state.copyWith(
          translatedMnemonic: translatedMnemonic.words,
          error: null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void onLanguageChanged(bip39.Language? value) {
    if (value == null) return;

    try {
      emit(state.copyWith(selectedLanguage: value, error: null));
      translate();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
