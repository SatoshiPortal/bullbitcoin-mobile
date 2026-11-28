import 'dart:async';
import 'dart:typed_data';

import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:rust_bindings/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';

import '../data/freeze_authority.dart';
import '../data/write/spend/spend_writer.dart' show WalletSpender;
import '../data/read/wallet_frame_mapper.dart';
import '../data/wallet_projections.dart';
import '../domain/coin_freezes.dart';
import '../domain/ports/freeze_store_port.dart';
import '../domain/ports/wallet_revision_reader_port.dart';
import '../domain/sync_failure.dart';
import '../domain/wallet_key.dart';
import '../domain/wallet_revision.dart';
import '../domain/wallet_values.dart';
import '../public/sync.dart';

/// A wallet that publishes the given values at revision 0. Set [load] to false
/// to exercise the first load. [frozen] seeds its [MemoryFreezeStore].
Future<Wallet> testWallet({
  required WalletKey key,
  Balances? balances,
  List<Coin> coins = const [],
  Set<Outpoint> frozen = const {},
  List<ChainTransaction> transactions = const [],
  AddressBook? addresses,
  List<Uint8List> ownedScripts = const [],
  List<Outpoint> ownedOutpoints = const [],
  bool stale = false,
  bool load = true,
  WalletSpender? spender,
  Future<void> Function()? beforeFirstFrame,
}) {
  final revision = WalletRevision(key: key, generation: 0, revision: 0);
  return _wallet(key, frozen: frozen, load: load, spender: spender, (_) async {
    if (beforeFirstFrame != null) await beforeFirstFrame();
    return WalletFrame(
      WalletFrameData(
        revision: revision,
        balances:
            balances ??
            Balances(
              confirmedSat: BigInt.zero,
              immatureSat: BigInt.zero,
              trustedPendingSat: BigInt.zero,
              untrustedPendingSat: BigInt.zero,
              spendableSat: BigInt.zero,
              totalSat: BigInt.zero,
            ),
        coins: CoinList(coins),
        transactions: ChainTransactionList(transactions),
        addresses:
            addresses ??
            AddressBook(
              receiveIndex: -1,
              changeIndex: -1,
              receive: const [],
              change: const [],
            ),
        ownership: OwnershipIndex(
          revision: revision,
          scripts: ownedScripts,
          outpoints: ownedOutpoints,
        ),
      ),
      stale: stale,
    );
  });
}

/// A loaded wallet mapped from a `bdk.Wallet` or `lwk.Wallet` the test built,
/// with the production mapper. The test keeps ownership of [native].
Future<Wallet> testWalletFromNative(Object native, {required WalletKey key}) {
  final revision = WalletRevision(key: key, generation: 0, revision: 0);
  return _wallet(key, (_) async {
    final data = switch (native) {
      final bdk.Wallet wallet => bitcoinFrameData(wallet, revision),
      final lwk.Wallet wallet => await liquidFrameData(wallet, revision),
      _ => throw ArgumentError('Not a native wallet: ${native.runtimeType}'),
    };
    return WalletFrame(data, stale: false);
  }, derive: native);
}

Future<Wallet> _wallet(
  WalletKey key,
  Future<WalletFrame> Function(WalletKey) frame, {
  Object? derive,
  Set<Outpoint> frozen = const {},
  bool load = true,
  WalletSpender? spender,
}) async {
  final projections = WalletProjections(
    revisions: _Revisions(key),
    changes: const Stream.empty(),
    source: _Source(frame, derive),
    freezes: FreezeAuthority(
      MemoryFreezeStore(frozen.map((o) => FrozenOutpoint(o, origin: key.id))),
    ),
  );
  // Test-support library (`package:sync/testing.dart`), imported from test/ only.
  // ignore: invalid_use_of_visible_for_testing_member
  final wallet = walletOver(projections, key, 0, spender: spender);
  if (!load) return wallet;
  switch (await wallet.load()) {
    case Ok():
      return wallet;
    case Err(:final failure):
      throw StateError('Test wallet failed to load: ${failure.logCode}');
  }
}

final class _Revisions implements WalletRevisionReaderPort {
  final WalletRevisionState _state;

  _Revisions(WalletKey key)
    : _state = WalletRevisionState(
        stamp: WalletRevision(key: key, generation: 0, revision: 0),
        lifecycle: WalletLifecycle.active,
        initializedSchema: 1,
      );

  @override
  Future<Result<WalletRevisionState, SyncFailure>> read(WalletKey key) async =>
      Ok(_state);

  @override
  Stream<WalletRevisionState> watch(WalletKey key) => const Stream.empty();
}

final class _Source implements FrameSource {
  final Future<WalletFrame> Function(WalletKey) _frame;
  final Object? _native;

  _Source(this._frame, this._native);

  @override
  Future<Result<LoadedFrame, SyncFailure>> load(
    WalletKey key,
    WalletFrame? current,
  ) async => Ok((frame: current ?? await _frame(key), admitted: true));

  @override
  Future<Result<DerivedAddress, SyncFailure>> derive(
    WalletKey key,
    Keychain keychain,
    int index,
  ) async => switch (_native) {
    final bdk.Wallet wallet => Ok(bitcoinAddress(wallet, keychain, index)),
    final lwk.Wallet wallet => Ok(await liquidAddress(wallet, index)),
    _ => const Err(SyncNotFoundFailure()),
  };
}

/// An in-memory [FreezeStorePort]. For tests only.
///
/// [failure], while set, fails every operation, as an unreadable store does.
final class MemoryFreezeStore implements FreezeStorePort {
  final _rows = <FrozenOutpoint>{};
  SyncFailure? failure;

  MemoryFreezeStore([Iterable<FrozenOutpoint> rows = const []]) {
    _rows.addAll(rows);
  }

  /// What the store holds, for assertions.
  Set<FrozenOutpoint> get rows => Set.unmodifiable(_rows);

  @override
  Future<Result<List<FrozenOutpoint>, SyncFailure>> readAll() async =>
      _answer(() => _rows.toList());

  @override
  Future<Result<void, SyncFailure>> freeze(List<FrozenOutpoint> rows) =>
      _answer(() => _rows.addAll(rows));

  @override
  Future<Result<void, SyncFailure>> unfreeze(List<Outpoint> outpoints) =>
      _answer(
        () => _rows.removeWhere((row) => outpoints.contains(row.outpoint)),
      );

  Future<Result<T, SyncFailure>> _answer<T>(T Function() body) async {
    final failure = this.failure;
    return failure == null ? Ok(body()) : Err(failure);
  }
}
