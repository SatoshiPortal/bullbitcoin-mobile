import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/bip85.dart';

import '../domain/bip85_failure.dart';
import '../domain/manage_bip85_usecase.dart';
import 'bip85_state.dart';

final class Bip85EntropyCubit extends Cubit<Bip85EntropyState> {
  final ManageBip85Usecase _usecase;
  late final StreamSubscription<bool> _lockSubscription;
  var _revocations = 0;
  var _started = false;

  /// [lockChanges] is true on every lock and false on every unlock. A lock
  /// clears what the old session revealed and drops every result still in
  /// flight, reload included; the next unlock reads again.
  Bip85EntropyCubit(this._usecase, Stream<bool> lockChanges)
    : super(const Bip85EntropyState()) {
    _lockSubscription = lockChanges.listen((locked) {
      if (isClosed) return;
      if (locked) {
        _revocations++;
        emit(const Bip85EntropyState());
      } else if (_started) {
        unawaited(_reload());
      }
    });
  }

  Future<void> init() {
    _started = true;
    return _reload();
  }

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
    final revocations = _revocations;
    final result = await command();
    if (isClosed || revocations != _revocations) return;
    switch (result) {
      case Err(:final failure):
        emit(state.copyWith(failure: failure, isLoading: false));
      case Ok():
        await _reload();
    }
  }

  Future<void> _reload() async {
    emit(state.copyWith(isLoading: true));
    final revocations = _revocations;
    final result = await _usecase.list();
    if (isClosed || revocations != _revocations) return;
    switch (result) {
      case Err(:final failure):
        emit(Bip85EntropyState(failure: failure));
      case Ok(:final value):
        emit(Bip85EntropyState(derivations: value));
    }
  }

  @override
  Future<void> close() async {
    await _lockSubscription.cancel();
    await super.close();
  }
}
