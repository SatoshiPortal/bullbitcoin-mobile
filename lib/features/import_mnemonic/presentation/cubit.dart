import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_wallet_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/scan_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ImportMnemonicCubit extends Cubit<ImportMnemonicState> {
  final ImportWalletUsecase _importWalletUsecase;
  final ScanMnemonicUsecase _scanMnemonicUsecase;
  final CheckDuplicateMnemonicUsecase _checkDuplicateMnemonicUsecase;

  ImportMnemonicCubit({
    required this._importWalletUsecase,
    required this._scanMnemonicUsecase,
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
        _scan(mnemonic, const {
          ScriptType.bip84,
          ScriptType.bip49,
          ScriptType.bip44,
        });
      case Err(:final failure):
        emit(state.copyWith(failure: failure, isLoading: false));
    }
  }

  /// Scans [scriptType] again after a failure. The import does not wait for it.
  Future<void> retryScan(ScriptType scriptType) async {
    final mnemonic = state.mnemonic;
    if (mnemonic == null || state.scanOf(scriptType) is! ScriptTypeScanFailed) {
      return;
    }
    await _scan(mnemonic, {scriptType});
  }

  Future<void> _scan(Mnemonic mnemonic, Set<ScriptType> scriptTypes) async {
    for (final scriptType in scriptTypes) {
      _emitScan(scriptType, const ScriptTypeScan.loading());
    }
    final scans = _scanMnemonicUsecase.execute(
      words: mnemonic.words,
      language: mnemonic.language,
      passphrase: mnemonic.passphrase,
      scriptTypes: scriptTypes,
    );
    // Emit each as it completes, so a slow scan for one type doesn't block the others.
    await Future.wait([
      for (final MapEntry(key: scriptType, value: scan) in scans.entries)
        scan.then((result) {
          // A result for a mnemonic the user has since replaced is dropped.
          if (isClosed || state.mnemonic != mnemonic) return;
          _emitScan(scriptType, switch (result) {
            Ok(:final value) => ScriptTypeScan.fromResult(value),
            Err(:final failure) => ScriptTypeScan.failed(failure),
          });
        }),
    ]);
  }

  void _emitScan(ScriptType scriptType, ScriptTypeScan scan) =>
      emit(switch (scriptType) {
        ScriptType.bip84 => state.copyWith(bip84Scan: scan),
        ScriptType.bip49 => state.copyWith(bip49Scan: scan),
        ScriptType.bip44 => state.copyWith(bip44Scan: scan),
      });

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
