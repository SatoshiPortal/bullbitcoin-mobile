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
    emit(state.copyWith(mnemonic: mnemonic, error: null));
    _scanAllScriptTypes(mnemonic);
  }

  Future<void> _scanAllScriptTypes(Mnemonic mnemonic) async {
    final bip39Mnemonic = bip39.Mnemonic.fromWords(
      words: mnemonic.words,
      passphrase: mnemonic.passphrase,
      language: mnemonic.language,
    );

    // Fire all three concurrently and emit each as it completes,
    // so a slow/failing scan for one type doesn't block the others.
    await Future.wait([
      _scanOne(bip39Mnemonic, ScriptType.bip84),
      _scanOne(bip39Mnemonic, ScriptType.bip49),
      _scanOne(bip39Mnemonic, ScriptType.bip44),
    ]);
  }

  Future<void> _scanOne(bip39.Mnemonic m, ScriptType scriptType) async {
    try {
      final result = await _checkWalletUsecase(
        mnemonic: m,
        scriptType: scriptType,
      );
      if (isClosed) return;
      switch (scriptType) {
        case ScriptType.bip84:
          emit(state.copyWith(bip84Status: result));
        case ScriptType.bip49:
          emit(state.copyWith(bip49Status: result));
        case ScriptType.bip44:
          emit(state.copyWith(bip44Status: result));
      }
    } catch (_) {
      // Per-script failures are intentionally not surfaced globally
      // so the other scans can still emit their results.
    }
  }

  void updateBip39Purpose(ScriptType scriptType) =>
      emit(state.copyWith(scriptType: scriptType));

  Future<void> import() async {
    try {
      if (state.mnemonic == null) throw MnemonicIsNullError();

      emit(state.copyWith(isLoading: true, error: null));

      final mnemonic = state.mnemonic!;
      final wallet = await _importWalletUsecase.execute(
        mnemonicWords: mnemonic.words,
        label: mnemonic.label,
        passphrase: mnemonic.passphrase,
        scriptType: state.scriptType,
      );
      emit(state.copyWith(wallet: wallet, isLoading: false));
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
