import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_wallet_status_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_wallet_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ImportMnemonicCubit extends Cubit<ImportMnemonicState> {
  final ImportWalletUsecase _importWalletUsecase;
  final CheckWalletStatusUsecase _checkWalletUsecase;
  final CheckDuplicateMnemonicUsecase _checkDuplicateMnemonicUsecase;

  ImportMnemonicCubit({
    required this._importWalletUsecase,
    required this._checkWalletUsecase,
    required this._checkDuplicateMnemonicUsecase,
  }) : super(const ImportMnemonicState());

  void clearFailure() => emit(state.copyWith(failure: null));

  void reset() => emit(const ImportMnemonicState());

  Future<void> updateMnemonic(Mnemonic mnemonic) async {
    if (mnemonic.label.isEmpty) {
      emit(state.copyWith(failure: const ImportMnemonicEmptyLabelFailure()));
      return;
    }

    emit(state.copyWith(isLoading: true, failure: null));

    switch (await _checkDuplicateMnemonicUsecase.execute(
      mnemonicWords: mnemonic.words,
      language: mnemonic.language,
      passphrase: mnemonic.passphrase,
    )) {
      case Ok():
        emit(state.copyWith(mnemonic: mnemonic, isLoading: false));
        _scanAllScriptTypes(mnemonic);
      case Err(:final failure):
        emit(state.copyWith(failure: failure, isLoading: false));
    }
  }

  Future<void> _scanAllScriptTypes(Mnemonic mnemonic) async {
    final Map<ScriptType, Future<({BigInt satoshis, int transactions})>> scans;
    try {
      // One derivation for the three script types; their scans then run concurrently.
      scans = await _checkWalletUsecase(
        words: mnemonic.words,
        language: mnemonic.language,
        passphrase: mnemonic.passphrase,
        scriptTypes: const {
          ScriptType.bip84,
          ScriptType.bip49,
          ScriptType.bip44,
        },
      );
    } catch (_) {
      // Without descriptors nothing is scanned; the import itself stays available.
      return;
    }
    // Emit each as it completes, so a slow/failing scan for one type doesn't block the others.
    await Future.wait([
      for (final MapEntry(key: scriptType, value: scan) in scans.entries)
        _emitScan(scriptType, scan),
    ]);
  }

  Future<void> _emitScan(
    ScriptType scriptType,
    Future<({BigInt satoshis, int transactions})> scan,
  ) async {
    try {
      final result = await scan;
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
    final mnemonic = state.mnemonic;
    if (mnemonic == null) {
      emit(state.copyWith(failure: const ImportMnemonicNullMnemonicFailure()));
      return;
    }

    emit(state.copyWith(isLoading: true, failure: null));

    switch (await _importWalletUsecase.execute(
      mnemonicWords: mnemonic.words,
      language: mnemonic.language,
      label: mnemonic.label,
      passphrase: mnemonic.passphrase,
      scriptType: state.scriptType,
    )) {
      case Ok(:final value):
        emit(state.copyWith(wallet: value, isLoading: false));
      case Err(:final failure):
        emit(state.copyWith(failure: failure, isLoading: false));
    }
  }
}
