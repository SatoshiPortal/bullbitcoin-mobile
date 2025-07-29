import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/import_wallet_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ImportMnemonicCubit extends Cubit<ImportMnemonicState> {
  final ImportWalletUsecase _importWalletUsecase;

  ImportMnemonicCubit({required ImportWalletUsecase importWalletUsecase})
    : _importWalletUsecase = importWalletUsecase,
      super(const ImportMnemonicState());

  void clearError() => emit(state.copyWith(error: null));

  void reset() => emit(const ImportMnemonicState());

  void updateMnemonic(Mnemonic mnemonic) =>
      emit(state.copyWith(mnemonic: mnemonic));

  void updateBip39Purpose(ScriptType scriptType) =>
      emit(state.copyWith(scriptType: scriptType));

  Future<void> import() async {
    if (state.mnemonic == null) {
      emit(state.copyWith(error: Exception('Mnemonic or script type is null')));
      return;
    }

    try {
      final mnemonic = state.mnemonic!;
      emit(state.copyWith(isLoading: true));
      final wallet = await _importWalletUsecase.execute(
        mnemonicWords: mnemonic.words,
        label: mnemonic.label,
        passphrase: mnemonic.passphrase,
        scriptType: state.scriptType,
      );
      emit(state.copyWith(wallet: wallet, isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: e as Exception, isLoading: false));
    }
  }
}
