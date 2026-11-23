import 'package:primitives/primitives.dart' show Failure, Fingerprint, Result;
import 'package:secrets/secrets.dart' show SeedReferencePort;
import 'package:swaps/swaps.dart' show Swap, SwapStore, SwapsFailure;
import 'package:sync/sync.dart' show SyncFailure, WalletKey;
import 'package:sync/write.dart' show WalletNativeLifecycle;

/// A native lifecycle that never touches a store. Calls are recorded so a test
/// can prove which stage of the deletion ran, and failure outcomes are scripted
/// per call.
final class FakeNativeLifecycle implements WalletNativeLifecycle {
  final List<WalletKey> deleted = [];
  final List<WalletKey> catalogDeletedKeys = [];

  /// Runs at the start of [delete], so a test can make the inventory
  /// unavailable to the steps that follow the native deletion.
  void Function()? beforeDelete;

  Result<void, SyncFailure> Function(WalletKey key)? deleteOutcome;
  Result<void, SyncFailure> Function(WalletKey key)? catalogDeletedOutcome;

  @override
  Future<Result<void, SyncFailure>> delete(WalletKey key) async {
    beforeDelete?.call();
    deleted.add(key);
    return deleteOutcome?.call(key) ?? const Ok(null);
  }

  @override
  Future<Result<void, SyncFailure>> catalogDeleted(WalletKey key) async {
    catalogDeletedKeys.add(key);
    return catalogDeletedOutcome?.call(key) ?? const Ok(null);
  }

  @override
  Future<Result<void, SyncFailure>> prepareCreate(WalletKey key) =>
      throw UnimplementedError('prepareCreate is not part of wallet deletion');

  @override
  Future<Result<void, SyncFailure>> create(WalletKey key) =>
      throw UnimplementedError('create is not part of wallet deletion');

  @override
  Future<Result<int?, SyncFailure>> issuedReceiveIndex(WalletKey key) =>
      throw UnimplementedError('issuedReceiveIndex is not part of deletion');

  @override
  Future<Result<({String address, int index}), SyncFailure>> receive(
    WalletKey key, {
    bool advance = false,
  }) => throw UnimplementedError('receive is not part of wallet deletion');
}

/// A swap store holding no swaps, or an outcome the test scripts.
final class FakeSwapStore implements SwapStore {
  FakeSwapStore({this.ongoingOutcome = const Ok<List<Swap>, SwapsFailure>([])});

  Result<List<Swap>, SwapsFailure> ongoingOutcome;
  final List<String?> ongoingQueries = [];

  @override
  Future<Result<List<Swap>, SwapsFailure>> ongoing({String? walletId}) async {
    ongoingQueries.add(walletId);
    return ongoingOutcome;
  }

  @override
  Future<Result<Swap, SwapsFailure>> get(String swapId) =>
      throw UnimplementedError('get is not part of wallet deletion');

  @override
  Stream<Swap> watch(String swapId) =>
      throw UnimplementedError('watch is not part of wallet deletion');

  @override
  Future<Result<List<Swap>, SwapsFailure>> all({String? walletId}) =>
      throw UnimplementedError('all is not part of wallet deletion');

  @override
  Future<Result<Swap?, SwapsFailure>> byTxId(String txId) =>
      throw UnimplementedError('byTxId is not part of wallet deletion');
}

/// A custody owner counted besides the wallet inventory. Its outcome is a
/// callback so a test can script references, an incomplete read or a throw.
final class FakeSeedOwner implements SeedReferencePort {
  FakeSeedOwner(this.outcome);

  final Future<Result<Set<Fingerprint>, Failure>> Function() outcome;
  int reads = 0;

  @override
  Future<Result<Set<Fingerprint>, Failure>> getCustodyFingerprints() {
    reads++;
    return outcome();
  }
}
