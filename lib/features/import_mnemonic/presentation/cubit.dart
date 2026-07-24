import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_compact_block_filters_available_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_status_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_wallet_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/state.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_bloc/flutter_bloc.dart';

class ImportMnemonicCubit extends Cubit<ImportMnemonicState> {
  final ImportWalletUsecase _importWalletUsecase;
  final CheckWalletStatusUsecase _checkWalletUsecase;
  final CheckDuplicateMnemonicUsecase _checkDuplicateMnemonicUsecase;
  final CheckCompactBlockFiltersAvailableUsecase
  _checkCompactBlockFiltersAvailableUsecase;

  ImportMnemonicCubit({
    required this._importWalletUsecase,
    required this._checkWalletUsecase,
    required this._checkDuplicateMnemonicUsecase,
    required this._checkCompactBlockFiltersAvailableUsecase,
  }) : super(const ImportMnemonicState());

  /// Loads whether the compact-block-filter choice should be offered at
  /// all. Fire-and-forget from the route's `BlocProvider.create` — a
  /// pending check simply keeps [ImportMnemonicState.isCbfAvailable] at its
  /// safe `false` default (Electrum-only UI) until this resolves.
  Future<void> init() async {
    final available = await _checkCompactBlockFiltersAvailableUsecase.execute();
    if (isClosed) return;
    emit(state.copyWith(isCbfAvailable: available));
  }

  void clearFailure() => emit(state.copyWith(failure: null));

  void reset() => emit(const ImportMnemonicState());

  void selectSyncBackend(BitcoinSyncBackend backend) =>
      emit(state.copyWith(syncBackend: backend, failure: null));

  /// `null` means "the earliest possible date" (this network's genesis
  /// block) — see [ImportMnemonicState.birthday]'s own doc.
  void updateBirthday(DateTime? birthday) =>
      emit(state.copyWith(birthday: birthday, failure: null));

  /// Falls back to the earliest possible birthday (genesis), which never
  /// requires a network lookup, and retries the import — the recovery path
  /// offered alongside a plain retry when
  /// [ImportMnemonicBirthdayCheckpointFailure] is surfaced.
  Future<void> retryImportWithGenesisBirthday() async {
    updateBirthday(null);
    await import();
  }

  Future<void> updateMnemonic(Mnemonic mnemonic) async {
    if (mnemonic.label.isEmpty) {
      emit(state.copyWith(failure: const ImportMnemonicEmptyLabelFailure()));
      return;
    }

    emit(state.copyWith(isLoading: true, failure: null));

    switch (await _checkDuplicateMnemonicUsecase.execute(
      mnemonicWords: mnemonic.words,
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
    if (state.mnemonic == null) {
      emit(state.copyWith(failure: const ImportMnemonicNullMnemonicFailure()));
      return;
    }

    emit(state.copyWith(isLoading: true, failure: null));

    final mnemonic = state.mnemonic!;
    switch (await _importWalletUsecase.execute(
      mnemonicWords: mnemonic.words,
      label: mnemonic.label,
      passphrase: mnemonic.passphrase,
      scriptType: state.scriptType,
      requestedSyncBackend: state.syncBackend,
      birthday: state.birthday,
    )) {
      case Ok(:final value):
        emit(state.copyWith(wallet: value, isLoading: false));
      case Err(:final failure):
        emit(state.copyWith(failure: failure, isLoading: false));
    }
  }
}
