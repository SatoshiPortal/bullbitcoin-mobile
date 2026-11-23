import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart' show WalletNativeLifecycle;

/// A scriptable native store: no engine, only the lifecycle the caller sees.
final class FakeNativeLifecycle implements WalletNativeLifecycle {
  Future<Result<void, SyncFailure>> Function(WalletKey key)? onCreate;
  Future<Result<void, SyncFailure>> Function(WalletKey key)? onPrepare;

  final List<WalletKey> prepared = [];
  final List<WalletKey> created = [];
  final List<WalletKey> deleted = [];
  final List<WalletKey> catalogDeletes = [];
  int receiveCalls = 0;

  @override
  Future<Result<void, SyncFailure>> prepareCreate(WalletKey key) {
    prepared.add(key);
    return onPrepare?.call(key) ?? Future.value(const Ok(null));
  }

  @override
  Future<Result<void, SyncFailure>> create(WalletKey key) {
    created.add(key);
    return onCreate?.call(key) ?? Future.value(const Ok(null));
  }

  @override
  Future<Result<void, SyncFailure>> delete(WalletKey key) {
    deleted.add(key);
    return Future.value(const Ok(null));
  }

  @override
  Future<Result<void, SyncFailure>> catalogDeleted(WalletKey key) {
    catalogDeletes.add(key);
    return Future.value(const Ok(null));
  }

  @override
  Future<Result<int?, SyncFailure>> issuedReceiveIndex(WalletKey key) async =>
      const Ok(null);

  @override
  Future<Result<({String address, int index}), SyncFailure>> receive(
    WalletKey key, {
    bool advance = false,
  }) {
    receiveCalls++;
    throw StateError('Provisioning must not advance addresses');
  }
}

/// Records the draft each owner receives and can refuse preparation.
final class FakePropertyStore implements WalletPropertyStore {
  final List<WalletPropertyDraft> drafts = [];
  Result<void, Failure> outcome = const Ok(null);

  @override
  Future<Result<void, Failure>> prepareWallet(WalletPropertyDraft wallet) async {
    drafts.add(wallet);
    return outcome;
  }
}

/// Admits every parent immediately, like the production port without the
/// cross-process lock.
final class FakeAdmission implements ParentCustodyAdmissionPort {
  final lease = FakeLease();
  int runs = 0;

  @override
  Future<Result<T, ParentCustodyFailure>> runExclusive<T>(
    Fingerprint parent,
    Future<Result<T, ParentCustodyFailure>> Function(ParentCustodyLease) action,
  ) {
    runs++;
    return action(lease);
  }
}

final class FakeLease implements ParentCustodyLease {
  ParentCustodyState state = ParentCustodyState.ready;
  int reconciled = 0;

  @override
  Result<ParentCustodyState, ParentCustodyFailure> readState() => Ok(state);

  @override
  Result<void, ParentCustodyFailure> markDeleting() {
    state = ParentCustodyState.deleting;
    return const Ok(null);
  }

  @override
  Result<void, ParentCustodyFailure> markDeleted() {
    state = ParentCustodyState.deleted;
    return const Ok(null);
  }

  @override
  Result<void, ParentCustodyFailure> reconcilePresent() {
    reconciled++;
    state = ParentCustodyState.ready;
    return const Ok(null);
  }
}

/// Completes only when the test releases it, to observe an interrupted write.
final class PausedCreate {
  final entered = Completer<void>();
  final _release = Completer<void>();

  Future<Result<void, SyncFailure>> pause() async {
    entered.complete();
    await _release.future;
    return const Ok(null);
  }

  void release() => _release.complete();
}
