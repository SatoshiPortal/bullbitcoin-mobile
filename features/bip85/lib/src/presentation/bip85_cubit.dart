import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/bip85.dart';

import '../domain/bip85_failure.dart';
import '../domain/manage_bip85_usecase.dart';
import 'bip85_state.dart';

final class Bip85EntropyCubit extends Cubit<Bip85EntropyState> {
  final ManageBip85Usecase _usecase;

  Bip85EntropyCubit(this._usecase) : super(const Bip85EntropyState());

  Future<void> init() => _reload();

  Future<void> deriveNextMnemonic() => _update(_usecase.nextMnemonic);

  Future<void> deriveNextHex() => _update(_usecase.nextHex);

  Future<void> aliasDerivation(Bip85Derivation derivation, String alias) =>
      _update(() => _usecase.rename(derivation, alias));

  Future<void> revokeDerivation(Bip85Derivation derivation) =>
      _update(() => _usecase.setActive(derivation, active: false));

  Future<void> activateDerivation(Bip85Derivation derivation) =>
      _update(() => _usecase.setActive(derivation, active: true));

  Future<void> _update<T>(
    Future<Result<T, Bip85Failure>> Function() command,
  ) async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true, failure: null));
    switch (await command()) {
      case Err(:final failure):
        if (!isClosed) emit(state.copyWith(failure: failure, isLoading: false));
      case Ok():
        if (!isClosed) await _reload();
    }
  }

  Future<void> _reload() async {
    emit(state.copyWith(isLoading: true));
    final result = await _usecase.list();
    if (isClosed) return;
    switch (result) {
      case Err(:final failure):
        emit(Bip85EntropyState(failure: failure));
      case Ok(:final value):
        emit(Bip85EntropyState(derivations: value));
    }
  }
}
