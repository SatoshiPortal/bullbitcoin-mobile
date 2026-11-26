import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

/// Only a consumer test fake; real exclusion/crash tests use SQLite.
final class FakeParentCustodyAdmission implements ParentCustodyAdmissionPort {
  ParentCustodyFailure? refusal;
  final Map<Fingerprint, _FakeState> _parents = {};
  @override
  Future<Result<T, ParentCustodyFailure>> runExclusive<T>(
    Fingerprint parent,
    Future<Result<T, ParentCustodyFailure>> Function(ParentCustodyLease) action,
  ) async {
    if (refusal case final failure?) return Err(failure);
    final state = _parents.putIfAbsent(parent, _FakeState.new);
    if (state.active) return const Err(ParentCustodyBusyFailure());
    state.active = true;
    final lease = _FakeLease(state);
    try {
      return await action(lease);
    } finally {
      lease.active = false;
      state.active = false;
    }
  }
}

final class _FakeState {
  bool active = false;
  ParentCustodyState value = ParentCustodyState.ready;
}

final class _FakeLease implements ParentCustodyLease {
  final _FakeState _state;
  bool active = true;
  _FakeLease(this._state);
  ParentCustodyState get state => _state.value;
  set state(ParentCustodyState value) => _state.value = value;
  @override
  Result<ParentCustodyState, ParentCustodyFailure> readState() =>
      active ? Ok(state) : const Err(ParentCustodyStateFailure());
  Result<void, ParentCustodyFailure> _set(
    ParentCustodyState from,
    ParentCustodyState to,
  ) {
    if (!active || state != from) return const Err(ParentCustodyStateFailure());
    state = to;
    return const Ok(null);
  }

  @override
  Result<void, ParentCustodyFailure> markDeleting() =>
      _set(ParentCustodyState.ready, ParentCustodyState.deleting);
  @override
  Result<void, ParentCustodyFailure> markDeleted() =>
      _set(ParentCustodyState.deleting, ParentCustodyState.deleted);
  @override
  Result<void, ParentCustodyFailure> reconcilePresent() =>
      _set(state, ParentCustodyState.ready);
}
