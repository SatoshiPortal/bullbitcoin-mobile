import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/src/data/wallet_projections.dart';
import 'package:sync/src/public/sync.dart' show walletOver;
import 'package:sync/sync.dart';
import 'package:sync/testing.dart' show MemoryFreezeStore, testWallet;
import 'package:sync/src/data/freeze_authority.dart';

void main() {
  final key = WalletKey(id: 'values', network: BitcoinNetwork.testnet);
  late _Revisions revisions;
  late _Source source;
  late WalletProjections projections;

  setUp(() {
    revisions = _Revisions(key);
    source = _Source()..revisions = revisions;
    projections = WalletProjections(
      freezes: FreezeAuthority(MemoryFreezeStore()),
      revisions: revisions,
      changes: revisions.changes.stream,
      source: source,
    );
  });
  tearDown(() => projections.close());

  Wallet wallet([int generation = 0]) =>
      walletOver(projections, key, generation);

  test(
    'nothing is published before a load; unavailable is never zero',
    () async {
      final handle = wallet();
      expect(handle.balances.now.status, ValueStatus.notLoaded);
      source.failure = const SyncBusyFailure();
      expect(await handle.load(), isA<Err<WalletRevision, SyncFailure>>());
      final balances = handle.balances.now;
      expect(balances.status, ValueStatus.unavailable);
      expect(balances.failure, isA<SyncBusyFailure>());
      expect(balances.data, isNull);
    },
  );

  test('every now read without an await sees one revision', () async {
    final handle = wallet();
    await loaded(handle);
    final seen = <(WalletRevision?, WalletRevision?, WalletRevision?)>[];
    // Whenever a watcher runs, the three values come from one frame.
    final subscription = handle.balances.watch().listen((_) {
      seen.add((
        handle.balances.now.revision,
        handle.coins.now.revision,
        handle.history.now.revision,
      ));
    });
    await pump();
    revisions.commit(balance: 5, coins: 1);
    await loaded(handle);
    await pump();
    await subscription.cancel();
    expect(seen, hasLength(2));
    for (final (balances, coins, transactions) in seen) {
      expect(coins, balances);
      expect(transactions, balances);
    }
    expect(seen.last.$1?.revision, 1);
    expect(handle.coins.now.data, hasLength(1));
  });

  test('address usage counts each paying transaction once', () async {
    const address = 'first-address';
    const spentAddress = 'spent-address';
    final handle = await testWallet(
      key: key,
      stale: true,
      transactions: [
        BitcoinTransaction(
          txid: 'received',
          feeSat: 12,
          vsize: 140,
          confirmationTime: null,
          inputs: [],
          outputs: [
            for (final (index, destination) in [
              (0, address),
              (1, address),
              (2, spentAddress),
            ])
              BitcoinOutput(
                vout: index,
                valueSat: BigInt.from(20),
                scriptPubkey: Uint8List(0),
                address: destination,
                isOwn: true,
                isChange: false,
              ),
          ],
          sentSat: 0,
          receivedSat: 60,
          isExplicitlyRbf: false,
        ),
      ],
      coins: [
        BitcoinCoin(
          outpoint: (txId: 'received', vout: 0),
          amountSat: BigInt.from(20),
          scriptPubkey: Uint8List(0),
          address: address,
          keychain: Keychain.external,
          confirmations: 1,
        ),
      ],
    );

    expect(handle.addresses.usage().fold((usage) => usage, (_) => null), {
      address: (balanceSat: BigInt.from(20), transactionCount: 1),
      spentAddress: (balanceSat: BigInt.zero, transactionCount: 1),
    });
  });

  test('unavailable address usage reports the frame failure', () async {
    final handle = wallet();
    source.failure = const SyncBusyFailure();
    expect(await handle.load(), isA<Err<WalletRevision, SyncFailure>>());
    expect(
      handle.addresses.usage().fold((_) => null, (failure) => failure),
      isA<SyncBusyFailure>(),
    );
  });

  test('a revision is mapped once for every consumer', () async {
    final first = wallet();
    final second = wallet();
    final events = [
      first.balances.watch().listen((_) {}),
      second.coins.watch().listen((_) {}),
      first.addresses.book.watch().listen((_) {}),
    ];
    await loaded(first);
    await loaded(second);
    await loaded(first);
    expect(source.maps, 1);
    revisions.commit(balance: 2);
    await loaded(second);
    expect(source.maps, 2);
    for (final subscription in events) {
      await subscription.cancel();
    }
  });

  test('watch emits the current value, then distinct changes only', () async {
    final handle = wallet();
    final balances = <WalletBalances>[];
    final coins = <WalletCoins>[];
    final a = handle.balances.watch().listen(balances.add);
    final b = handle.coins.watch().listen(coins.add);
    await pump();
    expect(balances.single.status, ValueStatus.notLoaded);
    await loaded(handle);
    // Same balance, new coins: only coins emit.
    revisions.commit(balance: 0, coins: 2);
    await loaded(handle);
    // Same data, now stale: a staleness change is never suppressed.
    revisions.commit(balance: 0, coins: 2, stale: true);
    await loaded(handle);
    await pump();
    expect(balances.map((value) => value.status), [
      ValueStatus.notLoaded,
      ValueStatus.ready,
      ValueStatus.stale,
    ]);
    expect(coins.map((value) => value.data?.length), [null, 0, 2, 2]);
    expect(coins.last.status, ValueStatus.stale);
    await a.cancel();
    await b.cancel();
  });

  test('a commit read in this isolate republishes without a load', () async {
    final handle = wallet();
    await loaded(handle);
    final values = <WalletBalances>[];
    final subscription = handle.balances.watch().listen(values.add);
    await pump();
    // A worker committed; the foreground's revision read emits the change.
    revisions.commit(balance: 7);
    revisions.changes.add(revisions.state);
    await pump();
    await pump();
    expect(values.last.data?.totalSat, BigInt.from(7));
    await subscription.cancel();
  });

  test('a handle never follows a delete or a re-import', () async {
    final old = wallet();
    await loaded(old);
    revisions.delete();
    revisions.changes.add(revisions.state);
    await pump();
    expect(old.balances.now.failure, isA<SyncNotFoundFailure>());
    revisions.reimport();
    final fresh = wallet(1);
    expect(await fresh.load(), isA<Ok<WalletRevision, SyncFailure>>());
    expect(fresh.balances.now.status, ValueStatus.ready);
    expect(old.balances.now.status, ValueStatus.unavailable);
    expect(old.balances.now.failure, isA<SyncNotFoundFailure>());
    expect(await old.load(), isA<Err<WalletRevision, SyncFailure>>());
  });

  test(
    'protocol queries refuse a revision older than the committed one',
    () async {
      final handle = wallet();
      expect(await handle.ownership(), isA<Ok<OwnershipIndex, SyncFailure>>());
      revisions.commit(balance: 1);
      source.lagging = true;
      expect(
        await handle.ownership(),
        isA<Err<OwnershipIndex, SyncFailure>>().having(
          (err) => err.failure,
          'failure',
          isA<SyncBusyFailure>(),
        ),
      );
      expect(await handle.unspent(), isA<Err<CoinList, SyncFailure>>());
      source.lagging = false;
      final index = await handle.ownership();
      expect(index, isA<Ok<OwnershipIndex, SyncFailure>>());
      final ownership = (index as Ok<OwnershipIndex, SyncFailure>).value;
      expect(ownership.ownsScript(Uint8List.fromList([1, 2])), isTrue);
      expect(ownership.ownsOutpoint((txId: 'spent', vout: 0)), isTrue);
      expect(ownership.ownsScript(Uint8List.fromList([9])), isFalse);
    },
  );

  test('an address beyond the book is derived on request', () async {
    final handle = wallet();
    await loaded(handle);
    final at = handle.addresses.at(40);
    expect(at.now.status, ValueStatus.notLoaded);
    expect(
      await at.watch().firstWhere((value) => value.status == ValueStatus.ready),
      isA<WalletAddressAt>().having(
        (value) => value.data?.address,
        'address',
        'addr-external-40',
      ),
    );
    expect(handle.addresses.at(0).now.data?.address, 'addr-external-0');
  });

  test('close publishes closed, ends streams and refuses commands', () async {
    final handle = wallet();
    await loaded(handle);
    final values = <WalletBalances>[];
    final done = Completer<void>();
    handle.balances.watch().listen(values.add, onDone: done.complete);
    await pump();
    await projections.close();
    await done.future;
    expect(values.last.status, ValueStatus.closed);
    expect(handle.balances.now.status, ValueStatus.closed);
    expect(
      await handle.load(),
      isA<Err<WalletRevision, SyncFailure>>().having(
        (err) => err.failure,
        'failure',
        isA<SyncClosedFailure>(),
      ),
    );
    expect(await handle.balances.watch().toList(), [
      isA<WalletBalances>().having(
        (v) => v.status,
        'status',
        ValueStatus.closed,
      ),
    ]);
  });
}

Future<void> pump() => Future<void>.delayed(Duration.zero);

Future<void> loaded(Wallet wallet) async =>
    expect(await wallet.load(), isA<Ok<WalletRevision, SyncFailure>>());

final class _Revisions implements WalletRevisionReaderPort {
  final WalletKey key;
  final changes = StreamController<WalletRevisionState>.broadcast();
  late WalletRevisionState state;
  int balance = 0;
  int coins = 0;

  _Revisions(this.key) {
    state = _state(0, 0);
  }

  WalletRevisionState _state(
    int generation,
    int revision, {
    WalletLifecycle lifecycle = WalletLifecycle.active,
    bool stale = false,
  }) => WalletRevisionState(
    stamp: WalletRevision(key: key, generation: generation, revision: revision),
    lifecycle: lifecycle,
    initializedSchema: 1,
    syncFailed: stale,
  );

  void commit({int balance = 0, int coins = 0, bool stale = false}) {
    this.balance = balance;
    this.coins = coins;
    state = _state(
      state.stamp.generation,
      state.stamp.revision + 1,
      stale: stale,
    );
  }

  void delete() => state = _state(
    state.stamp.generation,
    state.stamp.revision + 1,
    lifecycle: WalletLifecycle.deleted,
  );

  void reimport() => state = _state(state.stamp.generation + 1, 0);

  @override
  Future<Result<WalletRevisionState, SyncFailure>> read(WalletKey key) async =>
      Ok(state);

  @override
  Stream<WalletRevisionState> watch(WalletKey key) => changes.stream;

  Future<void> close() => changes.close();
}

/// Maps the fake revision into a frame; counts actual mappings.
final class _Source implements FrameSource {
  late _Revisions revisions;
  SyncFailure? failure;
  bool lagging = false;
  int maps = 0;
  WalletFrame? _lagged;

  @override
  Future<Result<LoadedFrame, SyncFailure>> load(
    WalletKey key,
    WalletFrame? current,
  ) async {
    final failure = this.failure;
    if (failure != null) return Err(failure);
    final lagged = _lagged;
    // A lagging reader serves its cache, which is never admitted.
    if (lagging && lagged != null) return Ok((frame: lagged, admitted: false));
    final state = _states.state;
    if (current != null && current.revision == state.stamp) {
      return Ok((
        frame: current.stale == state.syncFailed
            ? current
            : WalletFrame(current.data, stale: state.syncFailed),
        admitted: true,
      ));
    }
    maps++;
    final frame = WalletFrame(
      WalletFrameData(
        revision: state.stamp,
        balances: Balances(
          confirmedSat: BigInt.from(_states.balance),
          immatureSat: BigInt.zero,
          trustedPendingSat: BigInt.zero,
          untrustedPendingSat: BigInt.zero,
          spendableSat: BigInt.from(_states.balance),
          totalSat: BigInt.from(_states.balance),
        ),
        coins: CoinList([
          for (var i = 0; i < _states.coins; i++)
            LiquidCoin(
              outpoint: (txId: 'coin', vout: i),
              amountSat: BigInt.one,
              scriptPubkey: '00',
              standardAddress: 's',
              confidentialAddress: 'c',
              blockHeight: null,
            ),
        ]),
        transactions: ChainTransactionList(const []),
        addresses: AddressBook(
          receiveIndex: 0,
          changeIndex: -1,
          receive: [_address(Keychain.external, 0)],
          change: const [],
        ),
        ownership: OwnershipIndex(
          revision: state.stamp,
          scripts: [
            Uint8List.fromList([1, 2]),
          ],
          outpoints: [(txId: 'spent', vout: 0)],
        ),
      ),
      stale: state.syncFailed,
    );
    _lagged = frame;
    return Ok((frame: frame, admitted: true));
  }

  @override
  Future<Result<DerivedAddress, SyncFailure>> derive(
    WalletKey key,
    Keychain keychain,
    int index,
  ) async => Ok(_address(keychain, index));

  _Revisions get _states => revisions;

  static DerivedAddress _address(Keychain keychain, int index) =>
      DerivedAddress(
        keychain: keychain,
        index: index,
        address: 'addr-${keychain.name}-$index',
      );
}
