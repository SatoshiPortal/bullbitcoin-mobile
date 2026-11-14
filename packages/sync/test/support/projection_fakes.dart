import 'dart:async';
import 'dart:typed_data';

import 'package:primitives/primitives.dart';
import 'package:sync/src/data/wallet_projections.dart';
import 'package:sync/sync.dart';

/// A revision store whose state the test moves, with a hook run before each
/// read so a commit, a write or a delete can land between two reads.
final class ScriptedRevisions implements WalletRevisionReaderPort {
  final WalletKey key;
  final changes = StreamController<WalletRevisionState>.broadcast();
  late WalletRevisionState state;
  void Function()? beforeRead;

  ScriptedRevisions(this.key) {
    state = at(0, 0);
  }

  WalletRevisionState at(
    int generation,
    int revision, {
    WalletLifecycle lifecycle = WalletLifecycle.active,
    bool syncFailed = false,
  }) => WalletRevisionState(
    stamp: WalletRevision(key: key, generation: generation, revision: revision),
    lifecycle: lifecycle,
    initializedSchema: 1,
    syncFailed: syncFailed,
  );

  /// The worker committed the next revision.
  void commit({bool syncFailed = false}) => state = at(
    state.stamp.generation,
    state.stamp.revision + 1,
    syncFailed: syncFailed,
  );

  /// A writer holds the wallet: the revision is unchanged until it commits.
  void beginWrite() => state = at(
    state.stamp.generation,
    state.stamp.revision,
    lifecycle: WalletLifecycle.pendingWrite,
  );

  void delete() => state = at(
    state.stamp.generation,
    state.stamp.revision + 1,
    lifecycle: WalletLifecycle.deleted,
  );

  void reimport() => state = at(state.stamp.generation + 1, 0);

  /// What the foreground revision reader emits after reading a new state.
  void emit() => changes.add(state);

  @override
  Future<Result<WalletRevisionState, SyncFailure>> read(WalletKey key) async {
    beforeRead?.call();
    return Ok(state);
  }

  @override
  Stream<WalletRevisionState> watch(WalletKey key) => changes.stream;
}

/// Behaves like the native frame source over a reader: it hydrates the
/// committed revision, or serves its cached one when the writer holds the
/// wallet (a busy admission), marking that frame stale.
final class ScriptedSource implements FrameSource {
  final ScriptedRevisions revisions;

  /// Serve the cached frame, as the reader does when admission is busy.
  bool busy = false;

  /// Run when a load starts, before the reader answers.
  void Function()? onLoad;

  /// When set, the mapping stays suspended until the test completes it.
  Completer<void>? mapping;

  /// Completes once a load has hydrated and is mapping.
  Completer<void> mappingEntered = Completer<void>();

  int maps = 0;
  int derives = 0;
  WalletFrame? _cached;

  ScriptedSource(this.revisions);

  @override
  Future<Result<LoadedFrame, SyncFailure>> load(
    WalletKey key,
    WalletFrame? current,
  ) async {
    onLoad?.call();
    final cached = _cached;
    if (busy) {
      if (cached == null) return const Err(SyncBusyFailure());
      return Ok((frame: frame(cached.revision, stale: true), admitted: false));
    }
    final state = revisions.state;
    if (!mappingEntered.isCompleted) mappingEntered.complete();
    final suspended = mapping;
    if (suspended != null) await suspended.future;
    maps++;
    final mapped = frame(state.stamp, stale: state.syncFailed);
    _cached = mapped;
    return Ok((frame: mapped, admitted: true));
  }

  @override
  Future<Result<DerivedAddress, SyncFailure>> derive(
    WalletKey key,
    Keychain keychain,
    int index,
  ) async {
    derives++;
    return Ok(address(keychain, index));
  }

  static DerivedAddress address(Keychain keychain, int index) => DerivedAddress(
    keychain: keychain,
    index: index,
    address: 'addr-${keychain.name}-$index',
  );

  static WalletFrame frame(WalletRevision revision, {required bool stale}) =>
      WalletFrame(
        revision: revision,
        stale: stale,
        balances: Balances(
          confirmedSat: BigInt.from(revision.revision),
          immatureSat: BigInt.zero,
          trustedPendingSat: BigInt.zero,
          untrustedPendingSat: BigInt.zero,
          spendableSat: BigInt.from(revision.revision),
          totalSat: BigInt.from(revision.revision),
        ),
        coins: CoinList(const []),
        transactions: ChainTransactionList(const []),
        addresses: AddressBook(
          receiveIndex: 0,
          changeIndex: -1,
          receive: [address(Keychain.external, 0)],
          change: const [],
        ),
        ownership: OwnershipIndex(
          revision: revision,
          scripts: [
            Uint8List.fromList([revision.revision]),
          ],
          outpoints: const [],
        ),
      );
}
