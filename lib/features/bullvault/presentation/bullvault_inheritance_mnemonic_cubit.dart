import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/derive_bullvault_mnemonic_key_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/generate_bullvault_inheritance_mnemonic_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:secrets/secrets.dart'
    show EphemeralMnemonic, EphemeralMnemonicExtension, SecretWidgets, Language;

final class BullVaultInheritanceMnemonicCubit extends Cubit<BullVaultFailure?> {
  final GenerateBullVaultInheritanceMnemonicUsecase _generate;
  final DeriveBullVaultMnemonicKeyUsecase _derive;
  EphemeralMnemonic? _mnemonic;

  BullVaultInheritanceMnemonicCubit(this._generate, this._derive) : super(null);

  Future<Result<SecretWidgets, BullVaultFailure>> generate() async {
    final result = await _generate.execute();
    switch (result) {
      case Ok(:final value):
        if (isClosed) {
          value.dispose();
          return const Err(BullVaultCreationFailure());
        }
        _mnemonic?.dispose();
        _mnemonic = value;
        emit(null);
        return Ok(value.widgets);
      case Err(:final failure):
        if (!isClosed) emit(failure);
        return Err(failure);
    }
  }

  Future<Result<String, BullVaultFailure>> acceptGenerated(
    Network network,
  ) async {
    final mnemonic = _mnemonic;
    if (mnemonic == null) return const Err(BullVaultInvalidSignerFailure());
    return _derive.fromGenerated(mnemonic: mnemonic, network: network);
  }

  Future<Result<String, BullVaultFailure>> import(
    List<String> words,
    Network network, {
    required Language language,
  }) async {
    final result = await _derive.execute(
      words: words,
      network: network,
      language: language,
    );
    if (!isClosed) {
      emit(switch (result) {
        Ok() => null,
        Err(:final failure) => failure,
      });
    }
    return result;
  }

  @override
  Future<void> close() {
    _mnemonic?.dispose();
    _mnemonic = null;
    return super.close();
  }
}
