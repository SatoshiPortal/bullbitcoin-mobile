import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_status_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/import_wallet_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/errors.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/state.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_bloc/flutter_bloc.dart';

class ImportMnemonicCubit extends Cubit<ImportMnemonicState> {
  final ImportWalletUsecase _importWalletUsecase;
  final TheDirtyUsecase _checkWalletUsecase;

  ImportMnemonicCubit({
    required ImportWalletUsecase importWalletUsecase,
    required TheDirtyUsecase checkWalletUsecase,
  }) : _importWalletUsecase = importWalletUsecase,
       _checkWalletUsecase = checkWalletUsecase,
       super(const ImportMnemonicState());

  void clearError() => emit(state.copyWith(error: null));

  void reset() => emit(const ImportMnemonicState());

  void updateMnemonic(Mnemonic mnemonic) {
    if (mnemonic.label.isEmpty) throw EmptyMnemonicLabelError();
    emit(state.copyWith(mnemonic: mnemonic));
  }

  Future<void> checkWalletsStatusDirty() async {
    try {
      if (state.mnemonic == null) throw MnemonicIsNullError();

      emit(state.copyWith(hasCheckedWallets: true, error: null));

      final mnemonic = bip39.Mnemonic.fromWords(
        words: state.mnemonic!.words,
        passphrase: state.mnemonic!.passphrase,
        language: state.mnemonic!.language,
      );

      final bip84Status = await _checkWalletUsecase(mnemonic, ScriptType.bip84);
      if (!isClosed) emit(state.copyWith(bip84Status: bip84Status));

      final bip49Status = await _checkWalletUsecase(mnemonic, ScriptType.bip49);
      if (!isClosed) emit(state.copyWith(bip49Status: bip49Status));

      final bip44Status = await _checkWalletUsecase(mnemonic, ScriptType.bip44);
      if (!isClosed) emit(state.copyWith(bip44Status: bip44Status));
    } catch (e) {
      emit(state.copyWith(error: e as Exception));
    }
  }

  void updateBip39Purpose(ScriptType scriptType) =>
      emit(state.copyWith(scriptType: scriptType));

  Future<void> import() async {
    try {
      if (state.mnemonic == null) throw MnemonicIsNullError();

      emit(state.copyWith(isLoading: true, error: null));

      final mnemonic = state.mnemonic!;
      final wallets = await _importWalletUsecase.execute(
        mnemonicWords: mnemonic.words,
        label: mnemonic.label,
        passphrase: mnemonic.passphrase,
        scriptType: state.scriptType,
      );
      emit(state.copyWith(wallets: wallets, isLoading: false));
    } catch (e) {
      emit(
        state.copyWith(
          error: ImportMnemonicError(e.toString()),
          isLoading: false,
        ),
      );
    }
  }
}
