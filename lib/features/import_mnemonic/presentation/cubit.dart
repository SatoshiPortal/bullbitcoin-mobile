import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/discover_mnemonic_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_wallet_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/state.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_bloc/flutter_bloc.dart';

class ImportMnemonicCubit extends Cubit<ImportMnemonicState> {
  final ImportWalletUsecase _importWalletUsecase;
  final DiscoverMnemonicWalletsUsecase _discovery;
  int _generation = 0;
  final CheckDuplicateMnemonicUsecase _checkDuplicateMnemonicUsecase;

  ImportMnemonicCubit({
    required this._importWalletUsecase,
    required this._discovery,
    required this._checkDuplicateMnemonicUsecase,
  }) : super(const ImportMnemonicState());

  void clearFailure() => emit(state.copyWith(failure: null));

  void reset() {
    _generation++;
    emit(const ImportMnemonicState());
  }

  Future<void> updateMnemonic(Mnemonic mnemonic) async {
    if (mnemonic.label.trim().isEmpty) {
      emit(state.copyWith(failure: const ImportMnemonicEmptyLabelFailure()));
      return;
    }

    final generation = ++_generation;
    emit(const ImportMnemonicState(isLoading: true));

    final result = await _checkDuplicateMnemonicUsecase.execute(
      mnemonicWords: mnemonic.words,
      passphrase: mnemonic.passphrase,
    );
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Ok():
        emit(ImportMnemonicState(mnemonic: mnemonic));
      case Err(:final failure):
        emit(state.copyWith(failure: failure, isLoading: false));
    }
  }

  Future<void> confirmSource({
    required BitcoinSyncSource source,
    WalletBirthday? birthday,
    ScriptType scriptType = ScriptType.bip84,
  }) async {
    final mnemonic = state.mnemonic;
    if (mnemonic == null) return;
    final generation = ++_generation;
    emit(
      state.copyWith(
        source: source,
        birthday: birthday,
        scriptType: scriptType,
        sourceConfirmed: true,
        bip44Status: null,
        bip49Status: null,
        bip84Status: null,
      ),
    );
    await _discovery.execute(
      mnemonic: bip39.Mnemonic.fromWords(
        words: mnemonic.words,
        passphrase: mnemonic.passphrase,
        language: mnemonic.language,
      ),
      source: source,
      sourceConfirmed: state.sourceConfirmed,
      isActive: () => !isClosed && generation == _generation,
      onDiscovered: (script, preview) {
        switch (script) {
          case ScriptType.bip84:
            emit(state.copyWith(bip84Status: preview));
          case ScriptType.bip49:
            emit(state.copyWith(bip49Status: preview));
          case ScriptType.bip44:
            emit(state.copyWith(bip44Status: preview));
        }
      },
    );
  }

  void updateBip39Purpose(ScriptType scriptType) =>
      emit(state.copyWith(scriptType: scriptType));

  Future<void> import() async {
    if (state.isLoading) return;
    final generation = _generation;
    final mnemonic = state.mnemonic;
    if (mnemonic == null) {
      emit(state.copyWith(failure: const ImportMnemonicNullMnemonicFailure()));
      return;
    }

    emit(state.copyWith(isLoading: true, failure: null));

    if (!state.sourceConfirmed) {
      emit(
        state.copyWith(
          isLoading: false,
          failure: const ImportMnemonicSourceNotConfirmedFailure(),
        ),
      );
      return;
    }
    final result = await _importWalletUsecase.execute(
      mnemonicWords: mnemonic.words,
      label: mnemonic.label,
      passphrase: mnemonic.passphrase,
      scriptType: state.scriptType,
      birthday: state.birthday,
      bitcoinSyncSource: state.source,
    );
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(wallet: value, isLoading: false));
      case Err(:final failure):
        emit(state.copyWith(failure: failure, isLoading: false));
    }
  }
}
