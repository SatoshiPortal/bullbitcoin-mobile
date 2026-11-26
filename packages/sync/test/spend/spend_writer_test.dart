import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:bull_logger/bull_logger.dart' show log;
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sync/src/data/datasources/revision_store_datasource.dart';
import 'package:sync/src/data/datasources/spend_gate_store_datasource.dart';
import 'package:sync/src/data/native_store_paths.dart';
import 'package:sync/src/data/write/spend/native_spend.dart';
import 'package:sync/src/data/write/writer_lock.dart';
import 'package:sync/sync.dart';
import 'package:sync/src/domain/spend.dart' show signedForGeneration;
import 'package:sync/testing.dart' show MemoryFreezeStore;
import 'package:sync/write.dart';

import '../support/connections.dart';
import '../support/funding_reservations.dart';

// The policy around the native builder, with the builder faked: what each
// build, bump, consolidation and broadcast may spend, and what it hands out.
// spend_native_test.dart runs the real BDK builder.

Outpoint _coin(String c, [int vout = 0]) => (txId: c * 64, vout: vout);

final _a = _coin('a');
final _b = _coin('b');
final _c = _coin('c');

/// A transaction spending [inputs], in its consensus serialization.
Uint8List _transaction(List<Outpoint> inputs) {
  final bytes = BytesBuilder()..add([2, 0, 0, 0, inputs.length]);
  for (final input in inputs) {
    final txid = [
      for (var i = 0; i < 64; i += 2)
        int.parse(input.txId.substring(i, i + 2), radix: 16),
    ].reversed;
    bytes
      ..add(txid.toList())
      ..add([input.vout, 0, 0, 0, 0, 0xfd, 0xff, 0xff, 0xff]);
  }
  bytes
    ..add([1, 0x10, 0x27, 0, 0, 0, 0, 0, 0, 22, 0, 20])
    ..add(List.filled(20, 7))
    ..add([0, 0, 0, 0]);
  return bytes.toBytes();
}

/// Minimal PSBT with native-segwit witness prevouts; no signer or network.
String _fundingPsbt(
  List<Outpoint> inputs, {
  bool legacy = false,
  bool finalised = false,
}) {
  final tx = _transaction(inputs);
  final bytes = BytesBuilder()
    ..add([0x70, 0x73, 0x62, 0x74, 0xff, 1, 0, tx.length])
    ..add(tx)
    ..addByte(0);
  for (final _ in inputs) {
    final script = legacy
        ? [0x76, 0xa9, 20, ...List.filled(20, 7), 0x88, 0xac]
        : [0, 20, ...List.filled(20, 7)];
    final value = ByteData(8)..setUint64(0, 50000, Endian.little);
    bytes
      ..add([1, 1, 9 + script.length])
      ..add(value.buffer.asUint8List())
      ..addByte(script.length)
      ..add(script);
    if (finalised) bytes.add([1, 7, 0]);
    bytes.addByte(0);
  }
  bytes.addByte(0); // sole output map
  return base64Encode(bytes.toBytes());
}

SignedSpend signedForGenerationForTest(
  WalletKey key,
  int generation,
  List<int> bytes,
  SpendOwner? owner,
) => signedForGeneration(
  key: key,
  generation: generation,
  transaction: SignedBitcoinTransaction(bytes),
  owner: owner,
);

final class _Bitcoin implements NativeBitcoinSpend {
  final _Natives natives;
  _Bitcoin(this.natives);

  @override
  Set<Outpoint> unspent() => natives.coins.toSet();

  @override
  List<Outpoint>? transactionInputs(String txid) => natives.original;

  @override
  BuiltTransaction build(BitcoinSpendRequest request, Set<Outpoint> excluded) {
    natives.builds++;
    if (natives.refusal case final refusal?) throw SpendRefusal(refusal);
    final inputs =
        request.selected ??
        [
          for (final coin in natives.coins)
            if (natives.ignoreExclusions || !excluded.contains(coin)) coin,
        ].take(1).toList();
    return BuiltTransaction(
      natives.encode?.call(inputs) ?? 'psbt-${natives.builds}',
      natives.effectiveInputs ?? inputs,
    );
  }

  @override
  BuiltTransaction bumpFee(String txid, SpendFeeRate fee) {
    natives.builds++;
    return BuiltTransaction('bump-${natives.builds}', natives.bumpInputs);
  }

  @override
  bool paysAsRequested(String psbt, BitcoinSpendRequest request) =>
      natives.paysAsRequested;

  @override
  bool keepsPayees(String psbt, String txid) => true;

  @override
  Future<SignatureCheck> originalSignatures(String txid) async =>
      natives.signatures;

  @override
  String annotate(String psbt) => '$psbt+paths';

  @override
  bool persist() {
    final failure = natives.persistFailure;
    if (failure != null) throw failure;
    natives.persisted++;
    return natives.persistWrites;
  }

  @override
  void close() => natives.closed++;
}

final class _Liquid implements NativeLiquidSpend {
  @override
  Future<BigInt> amountToAddress(String pset, String address) async =>
      BigInt.zero;

  final _Natives natives;
  _Liquid(this.natives);

  @override
  Future<List<({Outpoint outpoint, bool confirmed})>> coins() async => [
    for (final coin in natives.coins) (outpoint: coin, confirmed: true),
  ];

  @override
  Future<String> build(
    LiquidSpendRequest request,
    Set<Outpoint>? inputs,
  ) async {
    final chosen = inputs ?? natives.coins.toSet();
    final pset = 'pset-${natives.psets.length}';
    natives.psets[pset] = chosen.toList();
    return pset;
  }

  @override
  Future<List<String>> consolidate(
    ConsolidationRequest request,
    List<Outpoint> coins,
  ) async {
    natives.explicitConsolidation = true;
    return [
      for (final coin in coins) natives.record('batch-${coin.txId[0]}', [coin]),
    ];
  }

  @override
  Future<List<String>> consolidateAll(ConsolidationRequest request) async => [
    for (final batch in natives.lwkBatches)
      natives.record('lwk-${batch.first.txId[0]}', batch),
  ];

  @override
  Future<LiquidPsetEffect> effect(String pset) async =>
      const LiquidPsetEffect(policyBalanceSat: -1100, feeSat: 100);

  @override
  void close() => natives.closed++;
}

final class _Natives implements NativeSpendSessions {
  List<Outpoint> coins = [];
  String Function(List<Outpoint>)? encode;
  List<Outpoint>? effectiveInputs;
  List<Outpoint>? original;
  List<Outpoint> bumpInputs = [];
  List<List<Outpoint>> lwkBatches = [];
  final Map<String, List<Outpoint>> psets = {};
  SignatureCheck signatures = SignatureCheck.valid;
  SyncFailure? refusal;
  Exception? persistFailure;
  bool persistWrites = false;
  bool paysAsRequested = true;
  bool ignoreExclusions = false;
  bool explicitConsolidation = false;
  int builds = 0;
  int persisted = 0;
  int opened = 0;
  int closed = 0;

  String record(String pset, List<Outpoint> inputs) {
    psets[pset] = inputs;
    return pset;
  }

  @override
  Future<NativeBitcoinSpend> bitcoin(BitcoinWalletDescriptor descriptor) async {
    opened++;
    return _Bitcoin(this);
  }

  @override
  Future<NativeLiquidSpend> liquid(LiquidWalletDescriptor descriptor) async {
    opened++;
    return _Liquid(this);
  }

  @override
  List<Outpoint> psetInputs(String pset) =>
      psets[pset] ??
      (throw const SpendRefusal(SyncInvalidTransactionFailure()));

  @override
  Future<Result<LiquidNetwork, SyncFailure>> liquidAddressNetwork(
    String address,
  ) async => const Ok(LiquidNetwork.testnet);
}

final class _Reservations implements InputReservationPort {
  List<InputReservation> held = [];
  SyncFailure? failure;

  @override
  Future<Result<List<InputReservation>, SyncFailure>> reservations() async {
    final failure = this.failure;
    return failure == null ? Ok(held) : Err(failure);
  }
}

final class _Transport {
  final sent = <SignedTransaction>[];
  Result<String, SyncFailure> reply = Ok('d' * 64);
  Future<void> Function()? during;

  Future<Result<String, SyncFailure>> send(
    SignedTransaction transaction,
    Network network,
  ) async {
    sent.add(transaction);
    await during?.call();
    return reply;
  }
}

final class _Catalog implements WalletCatalogPort {
  final List<PublicWalletDescriptor> wallets;
  _Catalog(this.wallets);

  @override
  Future<Result<PublicWalletDescriptor, SyncFailure>> find(
    WalletKey key,
  ) async => Ok(wallets.singleWhere((wallet) => wallet.key == key));

  @override
  Future<Result<List<PublicWalletDescriptor>, SyncFailure>> list() async =>
      Ok(wallets);
}

final class _Reserved implements ReservedAddressPort {
  @override
  Future<Result<bool, SyncFailure>> isReserved(
    WalletKey key,
    String address,
  ) async => const Ok(false);
}

void main() {
  late Directory dir;
  late ForegroundStores stores;
  late RevisionStoreDatasource revisions;
  late MemoryFreezeStore freezes;
  late _Natives natives;
  late _Reservations reservations;
  late _Transport transport;
  late SqliteFundingReservations funding;
  var storesClosed = false;

  final bitcoin = BitcoinWalletDescriptor(
    key: WalletKey(id: 'spender', network: BitcoinNetwork.testnet),
    scriptType: ScriptType.bip84,
    origin: 'public-fixture',
    externalDescriptor: 'wpkh(public/spender/0)',
    internalDescriptor: 'wpkh(public/spender/1)',
  );
  final liquid = LiquidWalletDescriptor(
    key: WalletKey(id: 'liquid', network: LiquidNetwork.testnet),
    scriptType: ScriptType.bip84,
    origin: 'public-fixture',
    combinedCtDescriptor: 'ct(slip77(public),elwpkh(public/liquid/*))',
  );
  final owner = SpendOwner(protocol: 'payjoin', session: 's1');
  final other = SpendOwner(protocol: 'payjoin', session: 's2');

  InputReservation reservation(
    Outpoint outpoint,
    SpendOwner by, {
    String walletId = 'spender',
  }) => InputReservation(
    outpoint: outpoint,
    protocol: by.protocol,
    session: by.session,
    walletId: walletId,
    network: BitcoinNetwork.testnet,
    state: 'proposed',
  );

  BitcoinSpendRequest pay({
    List<Outpoint>? selected,
    SpendOwner? by,
    Set<Outpoint> exclude = const {},
  }) => BitcoinSpendRequest(
    recipients: [SpendRecipient('tb1qrecipient', amountSat: 10000)],
    fee: SpendFeeRate(1000),
    selected: selected,
    selectedOnly: selected != null,
    owner: by,
    exclude: exclude,
  );

  int generation(WalletKey key) =>
      revisions.record(key)?.state.stamp.generation ?? -1;

  T ok<T>(Result<T, SyncFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => fail('Unexpected ${failure.logCode}'),
  };

  SyncFailure err<T>(Result<T, SyncFailure> result) => switch (result) {
    Ok() => fail('Expected a failure'),
    Err(:final failure) => failure,
  };

  setUp(() {
    storesClosed = false;
    dir = Directory.systemTemp.createTempSync('spend-writer-');
    freezes = MemoryFreezeStore();
    natives = _Natives()..coins = [_a, _b, _c];
    reservations = _Reservations();
    funding = SqliteFundingReservations('${dir.path}/funding.sqlite');
    transport = _Transport();
    stores = openForeground(
      documentsDirectory: dir.path,
      catalog: _Catalog([bitcoin, liquid]),
      reservedAddresses: _Reserved(),
      freezes: freezes,
      inputReservations: reservations,
      fundingReservations: funding,
      connections: FixtureConnections(const []),
      spendSessions: natives,
      spendTransport: transport.send,
    );
    revisions = RevisionStoreDatasource.openExisting(
      revisionStorePath(dir.path),
    );
    for (final descriptor in [bitcoin, liquid]) {
      revisions.begin(descriptor.key, WriteIntent.create);
      revisions.finish(descriptor.key, initializedDescriptor: descriptor);
    }
  });

  tearDown(() async {
    revisions.close();
    if (!storesClosed) await stores.close();
    funding.close();
    dir.deleteSync(recursive: true);
  });

  test(
    'sender and receiver cannot reserve the same input concurrently',
    () async {
      final entering = Completer<void>();
      final release = Completer<void>();
      final current = generation(bitcoin.key);
      var receiverWrites = 0;
      final sender = stores.spend.reservePayjoinInputs(
        bitcoin.key,
        current,
        {_a},
        owner.session,
        () async {
          entering.complete();
          await release.future;
          reservations.held = [reservation(_a, owner)];
        },
      );
      await entering.future;
      final receiver = stores.spend.reservePayjoinInputs(
        bitcoin.key,
        current,
        {_a},
        other.session,
        () async {
          receiverWrites++;
        },
      );
      try {
        expect(
          WriterLock.acquire(dir.path, bitcoin.key),
          isA<Err<WriterLock, SyncFailure>>(),
        );
        expect(receiverWrites, 0);
      } finally {
        release.complete();
      }
      ok(await sender);
      expect(err(await receiver), isA<SyncProtectedInputsFailure>());
      expect(receiverWrites, 0);
      expect(transport.sent, isEmpty);
    },
  );

  test('stale and frozen Payjoin inputs never reach session storage', () async {
    final current = generation(bitcoin.key);
    Future<void> unexpected() async => fail('Reservation must not be stored');
    expect(
      err(
        await stores.spend.reservePayjoinInputs(
          bitcoin.key,
          current + 1,
          {_a},
          owner.session,
          unexpected,
        ),
      ),
      isA<SyncNotFoundFailure>(),
    );
    ok(await stores.freezes.freeze([FrozenOutpoint(_a, origin: 'user')]));
    expect(
      err(
        await stores.spend.reservePayjoinInputs(
          bitcoin.key,
          current,
          {_a},
          owner.session,
          unexpected,
        ),
      ),
      isA<SyncProtectedInputsFailure>(),
    );
  });

  test(
    'an acknowledged write must expose the expected owner and outpoints',
    () async {
      final current = generation(bitcoin.key);
      final result = await stores.spend.reservePayjoinInputs(
        bitcoin.key,
        current,
        {_a, _b},
        owner.session,
        () async {
          reservations.held = [reservation(_a, owner), reservation(_b, other)];
        },
      );
      expect(err(result), isA<SyncProtectedInputsFailure>());
    },
  );

  group('prepareFunding', () {
    final arkOwner = SpendOwner(protocol: 'ark', session: 'board-1');
    const context = '{"output":0,"expiryHeight":1008}';

    Future<Result<UnsignedSpend, SyncFailure>> prepare({
      SpendOwner? by,
      List<Outpoint>? selected,
      int? gen,
      String metadata = context,
    }) => stores.spend.prepareFunding(
      bitcoin.key,
      gen ?? generation(bitcoin.key),
      pay(by: by ?? arkOwner, selected: selected),
      context: metadata,
    );

    setUp(() {
      natives.encode = _fundingPsbt;
    });

    test(
      'persists native revision then exact reservation before hand-out',
      () async {
        natives.persistWrites = true;
        funding.beforeReserve = () async {
          expect((natives.persisted, natives.closed), (1, 1));
          expect(revisions.record(bitcoin.key)?.intent, isNull);
          expect(revisions.record(bitcoin.key)?.state.stamp.revision, 2);
          expect(
            WriterLock.acquire(dir.path, bitcoin.key),
            isA<Err<WriterLock, SyncFailure>>(),
          );
        };
        final spend = ok(await prepare());
        expect(spend.owner, arkOwner);
        expect(spend.inputs, [_a]);
        expect(funding.encoded, spend.encoded);
        expect(ok(await funding.reservations()).single.outpoint, _a);
        final lock = ok(WriterLock.acquire(dir.path, bitcoin.key));
        lock.release();
      },
    );

    test('public wallet refuses an absent configured funding port', () async {
      final sync = Sync.foreground(
        documentsDirectory: dir.path,
        catalog: _Catalog([bitcoin]),
        reservedAddresses: _Reserved(),
        freezes: freezes,
        inputReservations: reservations,
        connections: FixtureConnections(const []),
      );
      try {
        final wallet = ok(await sync.wallet(bitcoin.key));
        expect(
          err(
            await wallet.tx.prepareFunding(pay(by: arkOwner), context: context),
          ),
          isA<SyncSpendRefusedFailure>(),
        );
        expect(natives.opened, 0);
      } finally {
        await sync.close();
      }
    });

    test(
      'close waits for an admitted reservation without disposing its stores',
      () async {
        final entered = Completer<void>();
        final release = Completer<void>();
        funding.beforeReserve = () async {
          entered.complete();
          await release.future;
        };
        final pending = prepare();
        await entered.future;
        var closed = false;
        final closing = stores.close().then((_) {
          closed = true;
        });
        await Future<void>.delayed(Duration.zero);
        expect(closed, isFalse);
        expect(
          WriterLock.acquire(dir.path, bitcoin.key),
          isA<Err<WriterLock, SyncFailure>>(),
        );
        release.complete();
        ok(await pending);
        await closing;
        storesClosed = true;
        expect(closed, isTrue);
      },
    );

    test(
      'a late Payjoin overlap refuses hand-out and keeps both obligations',
      () async {
        funding.beforeReserve = () async {
          reservations.held = [reservation(_a, owner)];
        };
        expect(err(await prepare()), isA<SyncProtectedInputsFailure>());
        expect(ok(await funding.reservations()).single.outpoint, _a);
        for (final by in [arkOwner, owner]) {
          expect(
            err(
              await stores.spend.broadcast(
                signedForGenerationForTest(
                  bitcoin.key,
                  generation(bitcoin.key),
                  _transaction([_a]),
                  by,
                ),
              ),
            ),
            isA<SyncProtectedInputsFailure>(),
          );
        }
        expect(transport.sent, isEmpty);
      },
    );

    test(
      'revision failure retains durable intent and never reserves funding',
      () async {
        final db = sqlite3.open(revisionStorePath(dir.path));
        db.execute(
          "CREATE TRIGGER refuse_revision BEFORE UPDATE ON revisions WHEN NEW.revision > OLD.revision BEGIN SELECT RAISE(ABORT, 'fixture'); END",
        );
        natives.persistWrites = true;
        try {
          expect(err(await prepare()), isA<SyncStorageFailure>());
          expect(funding.calls, 0);
          expect(revisions.record(bitcoin.key)?.intent, WriteIntent.load);
          expect((natives.persisted, natives.closed), (1, 1));
        } finally {
          db.execute('DROP TRIGGER refuse_revision');
          db.close();
        }
        expect(err(await prepare()), isA<SyncSpendBlockedFailure>());
      },
    );

    test(
      'pending broadcasts block preparation before native or reservation work',
      () async {
        ok(
          await stores.spend.broadcast(
            signedForGenerationForTest(
              bitcoin.key,
              generation(bitcoin.key),
              _transaction([_a]),
              null,
            ),
          ),
        );
        final failure = err(await prepare()) as SyncSpendBlockedFailure;
        expect(failure.status, BitcoinSpendStatus.pending);
        expect(natives.opened, 0);
        expect(funding.calls, 0);
      },
    );

    for (final expected in [
      BitcoinSpendStatus.ready,
      BitcoinSpendStatus.pending,
    ]) {
      test(
        'rechecks readiness after slow funding releases its lease: $expected',
        () async {
          final key = bitcoin.key;
          final readiness = stores.spend.readiness(key);
          Future<void> published(BitcoinSpendStatus status) => readiness
              .watch()
              .firstWhere((value) => value.data == status)
              .timeout(const Duration(seconds: 3))
              .then((_) {});
          await published(BitcoinSpendStatus.ready);
          natives.persistWrites = true;
          final entered = Completer<void>();
          final release = Completer<void>();
          funding.beforeReserve = () async {
            entered.complete();
            await release.future;
          };
          final pending = prepare();
          await entered.future;
          try {
            // Revision publication asks the guard while funding still owns the lease. Let that real acquisition budget expire before releasing it.
            await published(BitcoinSpendStatus.busy);
            if (expected == BitcoinSpendStatus.pending) {
              final gate = SpendGateStoreDatasource.openExisting(
                spendGateStorePath(dir.path),
              );
              try {
                gate.accepted(bitcoin, generation(key), 'd' * 64);
              } finally {
                gate.close();
              }
            }
            release.complete();
            ok(await pending);
            // No explicit check(), native revision or other event should be needed. The fresh guard verdict may still refuse a spend.
            await published(expected);
          } finally {
            if (!release.isCompleted) release.complete();
            await pending;
          }
        },
      );
    }

    test('holds admission beyond wait budget and serializes freezes', () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      funding.beforeReserve = () async {
        entered.complete();
        await release.future;
      };
      final pending = prepare();
      await entered.future;
      try {
        for (final by in <SpendOwner?>[null, owner]) {
          final rejected = await stores.spend.broadcast(
            signedForGenerationForTest(
              bitcoin.key,
              generation(bitcoin.key),
              _transaction([_a]),
              by,
            ),
          );
          expect(err(rejected), isA<SyncBusyFailure>());
        }
        expect(transport.sent, isEmpty);
        expect(
          WriterLock.acquire(dir.path, bitcoin.key),
          isA<Err<WriterLock, SyncFailure>>(),
        );
        var frozen = false;
        final freezing = stores.freezes
            .freeze([FrozenOutpoint(_a, origin: 'user')])
            .then((value) {
              frozen = true;
              return value;
            });
        await Future<void>.delayed(Duration.zero);
        expect(frozen, isFalse);
        release.complete();
        ok(await pending);
        ok(await freezing);
      } finally {
        if (!release.isCompleted) release.complete();
        await pending;
      }
    });

    test('waits behind an admitted ordinary or Payjoin broadcast', () async {
      for (final by in <SpendOwner?>[null, owner]) {
        final entered = Completer<void>();
        final release = Completer<void>();
        transport.during = () async {
          entered.complete();
          await release.future;
        };
        transport.reply = const Err(SyncConnectionFailure());
        final sending = stores.spend.broadcast(
          signedForGenerationForTest(
            bitcoin.key,
            generation(bitcoin.key),
            _transaction([_a]),
            by,
          ),
        );
        await entered.future;
        try {
          expect(err(await prepare()), isA<SyncBusyFailure>());
          expect(natives.builds, 0);
          expect(funding.calls, 0);
        } finally {
          release.complete();
          await sending;
        }
      }
    });

    test(
      'reservation failure grants nothing; uncertain commit stays protected',
      () async {
        funding.failBeforeCommit = true;
        expect(err(await prepare()), isA<SyncStorageFailure>());
        expect(ok(await funding.reservations()), isEmpty);
        funding.failBeforeCommit = false;
        funding.failAfterCommit = true;
        expect(err(await prepare()), isA<SyncStorageFailure>());
        expect(ok(await funding.reservations()).single.outpoint, _a);
        expect(
          err(
            await stores.spend.build(
              bitcoin.key,
              generation(bitcoin.key),
              pay(selected: [_a]),
            ),
          ),
          isA<SyncProtectedInputsFailure>(),
        );
        expect(
          err(
            await stores.spend.broadcast(
              signedForGenerationForTest(
                bitcoin.key,
                generation(bitcoin.key),
                _transaction([_a]),
                owner,
              ),
            ),
          ),
          isA<SyncProtectedInputsFailure>(),
        );
        expect(transport.sent, isEmpty);
        await stores.close();
        funding.close();
        funding = SqliteFundingReservations('${dir.path}/funding.sqlite');
        stores = openForeground(
          documentsDirectory: dir.path,
          catalog: _Catalog([bitcoin, liquid]),
          reservedAddresses: _Reserved(),
          freezes: freezes,
          inputReservations: reservations,
          fundingReservations: funding,
          connections: FixtureConnections(const []),
          spendSessions: natives,
          spendTransport: transport.send,
        );
        expect(ok(await funding.reservations()).single.outpoint, _a);
        expect(
          err(
            await stores.spend.broadcast(
              signedForGenerationForTest(
                bitcoin.key,
                generation(bitcoin.key),
                _transaction([_a]),
                owner,
              ),
            ),
          ),
          isA<SyncProtectedInputsFailure>(),
        );
      },
    );

    test('identical owner retry is idempotent; changed transaction/context refused', () async {
      final first = ok(await prepare(selected: [_a]));
      final repeated = ok(await prepare(selected: [_a]));
      expect(repeated.encoded, first.encoded);
      expect(ok(await funding.reservations()), hasLength(1));
      expect(
        err(await prepare(selected: [_b])),
        isA<SyncSpendRefusedFailure>(),
      );
      expect(
        err(await prepare(selected: [_a], metadata: 'changed')),
        isA<SyncSpendRefusedFailure>(),
      );
      final conflicting = first; // host enforces atomic outpoint uniqueness too
      expect(
        err(
          await funding.reserve(
            key: bitcoin.key,
            spend: UnsignedSpend(
              revision: conflicting.revision,
              encoded: conflicting.encoded,
              inputs: conflicting.inputs,
              owner: other,
            ),
            context: context,
          ),
        ),
        isA<SyncSpendRefusedFailure>(),
      );
    });

    test(
      'successful funding rearms failure diagnostics for the next episode',
      () async {
        final messages = <String>[];
        final subscription = log.logger.logger.onRecord.listen((record) {
          if (record.message.contains(
            'Wallet writer unexpected storage failure category=storage',
          )) {
            messages.add(record.message);
          }
        });
        try {
          funding.failBeforeCommit = true;
          expect(err(await prepare()), isA<SyncStorageFailure>());
          expect(err(await prepare()), isA<SyncStorageFailure>());
          await Future<void>.delayed(Duration.zero);
          expect(messages, hasLength(1));
          funding.failBeforeCommit = false;
          ok(await prepare());
          funding.beforeReserve = () async {
            throw const FormatException('fixture reserve');
          };
          expect(err(await prepare()), isA<SyncStorageFailure>());
          await Future<void>.delayed(Duration.zero);
          expect(messages, hasLength(2));
        } finally {
          await subscription.cancel();
        }
      },
    );

    test(
      'native persistence and policy read failures never reach reserve',
      () async {
        natives.persistFailure = const FormatException('fixture persist');
        expect(err(await prepare()), isA<SyncStorageFailure>());
        expect(funding.calls, 0);
        natives.persistFailure = null;
        funding.readFailure = const SyncStorageFailure();
        expect(err(await prepare()), isA<SyncStorageFailure>());
        expect(funding.calls, 0);
        expect(
          err(
            await stores.spend.build(
              bitcoin.key,
              generation(bitcoin.key),
              pay(),
            ),
          ),
          isA<SyncStorageFailure>(),
        );
        expect(
          err(
            await stores.spend.broadcast(
              signedForGenerationForTest(
                bitcoin.key,
                generation(bitcoin.key),
                _transaction([_a]),
                null,
              ),
            ),
          ),
          isA<SyncStorageFailure>(),
        );
        expect(transport.sent, isEmpty);
        funding.readFailure = null;
        funding.beforeReserve = () async {
          throw const FormatException('fixture reserve');
        };
        expect(err(await prepare()), isA<SyncStorageFailure>());
        expect(ok(await funding.reservations()), isEmpty);
      },
    );

    test(
      'effective inputs, owner scope and freezes remain authoritative',
      () async {
        reservations.held = [reservation(_a, owner)];
        expect(
          err(await prepare(selected: [_a])),
          isA<SyncProtectedInputsFailure>(),
        );
        expect(
          err(
            await prepare(
              selected: [_a],
              by: SpendOwner(protocol: owner.protocol, session: 'other'),
            ),
          ),
          isA<SyncProtectedInputsFailure>(),
        );
        reservations.held = [reservation(_a, arkOwner, walletId: 'elsewhere')];
        expect(
          err(await prepare(selected: [_a])),
          isA<SyncProtectedInputsFailure>(),
        );
        reservations.held = [];
        ok(await stores.freezes.freeze([FrozenOutpoint(_a, origin: 'user')]));
        expect(
          err(await prepare(selected: [_a])),
          isA<SyncProtectedInputsFailure>(),
        );
        ok(await stores.freezes.unfreeze([_a]));
        natives.effectiveInputs = [_b];
        expect(
          err(await prepare(selected: [_a])),
          isA<SyncInvalidTransactionFailure>(),
        );
        expect(funding.calls, 0);
      },
    );

    test(
      'refuses missing owner, stale generation, invalid context and PSBT',
      () async {
        expect(
          err(
            await stores.spend.prepareFunding(
              bitcoin.key,
              generation(bitcoin.key),
              pay(),
              context: context,
            ),
          ),
          isA<SyncSpendRefusedFailure>(),
        );
        expect(
          err(await prepare(gen: generation(bitcoin.key) + 1)),
          isA<SyncNotFoundFailure>(),
        );
        for (final metadata in ['', 'x' * 4097, 'é' * 2049]) {
          expect(
            err(await prepare(metadata: metadata)),
            isA<SyncSpendRefusedFailure>(),
          );
        }
        for (final encode in <String Function(List<Outpoint>)>[
          (_) => 'invalid',
          (inputs) => _fundingPsbt(inputs, legacy: true),
          (inputs) => _fundingPsbt(inputs, finalised: true),
        ]) {
          natives.encode = encode;
          expect(err(await prepare()), isA<SyncInvalidTransactionFailure>());
        }
        expect(funding.calls, 0);
      },
    );
  });

  group('build', () {
    test('hands out the transaction with the committed revision', () async {
      final key = bitcoin.key;
      final unsigned = ok(
        await stores.spend.build(key, generation(key), pay()),
      );
      expect(unsigned.inputs, [_a]);
      expect(unsigned.revision, revisions.record(key)?.state.stamp);
      expect(revisions.record(key)?.intent, isNull);
      expect((natives.opened, natives.persisted, natives.closed), (1, 1, 1));
    });

    test('a persisted change commits a new revision before hand-out', () async {
      final key = bitcoin.key;
      final before = revisions.record(key)?.state.stamp.revision ?? -1;
      natives.persistWrites = true;
      final unsigned = ok(
        await stores.spend.build(key, generation(key), pay()),
      );
      expect(unsigned.revision.revision, before + 1);
      expect(revisions.record(key)?.state.stamp, unsigned.revision);
    });

    test('a persistence failure hands nothing out', () async {
      final key = bitcoin.key;
      natives.persistFailure = Exception('disk full');
      final failure = err(
        await stores.spend.build(key, generation(key), pay()),
      );
      expect(failure, isA<SyncStorageFailure>());
      expect(natives.closed, 1);
    });

    test('a frozen coin is avoided, and refused when selected', () async {
      final key = bitcoin.key;
      ok(await stores.freezes.freeze([FrozenOutpoint(_a, origin: 'x')]));
      expect(ok(await stores.spend.build(key, generation(key), pay())).inputs, [
        _b,
      ]);
      final failure = err(
        await stores.spend.build(key, generation(key), pay(selected: [_a])),
      );
      expect((failure as SyncProtectedInputsFailure).frozen, {_a});
      expect(natives.builds, 1);
    });

    test('the post-condition refuses a protected input the builder used, '
        'and still persists', () async {
      final key = bitcoin.key;
      ok(await stores.freezes.freeze([FrozenOutpoint(_a, origin: 'x')]));
      natives.ignoreExclusions = true;
      final failure = err(
        await stores.spend.build(key, generation(key), pay()),
      );
      expect((failure as SyncProtectedInputsFailure).frozen, {_a});
      expect((natives.persisted, natives.closed), (1, 1));
    });

    test('another session\'s reservation is avoided and refused; its owner '
        'alone may spend it', () async {
      final key = bitcoin.key;
      reservations.held = [reservation(_a, owner)];
      expect(ok(await stores.spend.build(key, generation(key), pay())).inputs, [
        _b,
      ]);
      expect(
        (err(
          await stores.spend.build(key, generation(key), pay(selected: [_a])),
        ) as SyncProtectedInputsFailure).reserved,
        {_a},
      );
      expect(
        err(
          await stores.spend.build(
            key,
            generation(key),
            pay(selected: [_a], by: other),
          ),
        ),
        isA<SyncProtectedInputsFailure>(),
      );
      final mine = ok(
        await stores.spend.build(
          key,
          generation(key),
          pay(selected: [_a], by: owner),
        ),
      );
      expect(mine.inputs, [_a]);
      expect(mine.owner, owner);
    });

    test('a reservation for another wallet is no exemption', () async {
      final key = bitcoin.key;
      reservations.held = [reservation(_a, owner, walletId: 'elsewhere')];
      expect(
        err(
          await stores.spend.build(
            key,
            generation(key),
            pay(selected: [_a], by: owner),
          ),
        ),
        isA<SyncProtectedInputsFailure>(),
      );
    });

    test('a freeze is never exempted, even for the reserving owner', () async {
      final key = bitcoin.key;
      reservations.held = [reservation(_a, owner)];
      ok(await stores.freezes.freeze([FrozenOutpoint(_a, origin: 'x')]));
      final failure = err(
        await stores.spend.build(
          key,
          generation(key),
          pay(selected: [_a], by: owner),
        ),
      );
      expect((failure as SyncProtectedInputsFailure).frozen, {_a});
    });

    test(
      'unreadable protections refuse the build, never read as none',
      () async {
        final key = bitcoin.key;
        reservations.failure = const SyncStorageFailure();
        expect(
          err(await stores.spend.build(key, generation(key), pay())),
          isA<SyncStorageFailure>(),
        );
        reservations.failure = null;
        freezes.failure = const SyncStorageFailure();
        expect(
          err(await stores.spend.build(key, generation(key), pay())),
          isA<SyncStorageFailure>(),
        );
        expect(natives.opened, 0);
      },
    );

    test('a transaction that does not pay as asked is refused', () async {
      final key = bitcoin.key;
      natives.paysAsRequested = false;
      expect(
        err(await stores.spend.build(key, generation(key), pay())),
        isA<SyncSpendRefusedFailure>(),
      );
    });

    test('a stale generation is refused before any native open', () async {
      final key = bitcoin.key;
      expect(
        err(await stores.spend.build(key, generation(key) + 1, pay())),
        isA<SyncNotFoundFailure>(),
      );
      expect(natives.opened, 0);
    });

    test('a pending broadcast blocks the next build', () async {
      final key = bitcoin.key;
      final unsigned = ok(
        await stores.spend.build(key, generation(key), pay()),
      );
      ok(
        await stores.spend.broadcast(
          unsigned.signed(
            SignedBitcoinTransaction(_transaction(unsigned.inputs)),
          ),
        ),
      );
      final failure = err(
        await stores.spend.build(key, generation(key), pay()),
      );
      expect(
        (failure as SyncSpendBlockedFailure).status,
        BitcoinSpendStatus.pending,
      );
      expect(stores.spend.readiness(key).now.data, BitcoinSpendStatus.pending);
    });
  });

  group('bump', () {
    final txid = 'e' * 64;

    test('builds only on an original whose signatures verify', () async {
      final key = bitcoin.key;
      natives
        ..original = [_a]
        ..bumpInputs = [_a]
        ..signatures = SignatureCheck.invalid;
      final failure = err(
        await stores.spend.bump(
          key,
          generation(key),
          BumpFeeRequest(txid: txid, fee: SpendFeeRate(2000)),
        ),
      );
      expect(
        (failure as SyncOriginalSignaturesFailure).check,
        SignatureCheck.invalid,
      );
      expect(natives.builds, 0);
    });

    test('refuses an original input frozen since, whoever bumps', () async {
      final key = bitcoin.key;
      natives
        ..original = [_a]
        ..bumpInputs = [_a];
      reservations.held = [reservation(_a, owner)];
      ok(await stores.freezes.freeze([FrozenOutpoint(_a, origin: 'x')]));
      final failure = err(
        await stores.spend.bump(
          key,
          generation(key),
          BumpFeeRequest(txid: txid, fee: SpendFeeRate(2000), owner: owner),
        ),
      );
      expect((failure as SyncProtectedInputsFailure).frozen, {_a});
    });

    test('the owner keeps its original inputs, never an added one', () async {
      final key = bitcoin.key;
      natives
        ..original = [_a]
        ..bumpInputs = [_a];
      reservations.held = [reservation(_a, owner), reservation(_b, owner)];
      Future<Result<UnsignedSpend, SyncFailure>> bump({SpendOwner? by}) =>
          stores.spend.bump(
            key,
            generation(key),
            BumpFeeRequest(txid: txid, fee: SpendFeeRate(2000), owner: by),
          );
      expect(err(await bump()), isA<SyncProtectedInputsFailure>());
      final replacement = ok(await bump(by: owner));
      expect(replacement.inputs, [_a]);
      expect(replacement.replacing, txid);

      natives.bumpInputs = [_a, _b];
      final failure = err(await bump(by: owner));
      expect((failure as SyncProtectedInputsFailure).reserved, {_b});
    });
  });

  group('consolidation', () {
    test('every batch is checked against the freezes', () async {
      final key = liquid.key;
      natives.lwkBatches = [
        [_a],
        [_b, _c],
      ];
      expect(
        ok(
          await stores.spend.consolidate(
            key,
            generation(key),
            ConsolidationRequest(
              fee: SpendFeeRate(100),
              highUtxoThreshold: 1,
              maximumInputs: 2,
            ),
          ),
        ).map((spend) => spend.inputs),
        [
          [_a],
          [_b, _c],
        ],
      );

      ok(await stores.freezes.freeze([FrozenOutpoint(_c, origin: 'x')]));
      final batches = ok(
        await stores.spend.consolidate(
          key,
          generation(key),
          ConsolidationRequest(
            fee: SpendFeeRate(100),
            highUtxoThreshold: 1,
            maximumInputs: 2,
          ),
        ),
      );
      expect(natives.explicitConsolidation, isTrue);
      expect(batches.expand((spend) => spend.inputs), [_a, _b]);
    });

    test('a batch the helper builds over a freeze refuses them all', () async {
      final key = liquid.key;
      // LWK's own helper sees no freeze when the store read is the only one
      // that knows it: the check on its batches is what refuses.
      natives
        ..coins = [_a, _b]
        ..lwkBatches = [
          [_a],
          [_c],
        ];
      ok(await stores.freezes.freeze([FrozenOutpoint(_c, origin: 'x')]));
      final failure = err(
        await stores.spend.consolidate(
          key,
          generation(key),
          ConsolidationRequest(
            fee: SpendFeeRate(100),
            highUtxoThreshold: 0,
            maximumInputs: 1,
          ),
        ),
      );
      expect((failure as SyncProtectedInputsFailure).frozen, {_c});
    });
  });

  group('broadcast', () {
    for (final asPsbt in [false, true]) {
      test('acceptance persists the actual broadcast inputs before observation '
          '(PSBT=$asPsbt)', () async {
        // Saved/signed bytes may contain inputs that differ from an earlier
        // build. The obligation must describe the bytes actually sent.
        final transaction = asPsbt
            ? SignedPsbt(_fundingPsbt([_b, _c], finalised: true))
            : SignedBitcoinTransaction(_transaction([_b, _c]));
        final receipt = ok(
          await stores.spend.broadcast(
            signedForGeneration(
              key: bitcoin.key,
              generation: generation(bitcoin.key),
              transaction: transaction,
            ),
          ),
        );
        expect(receipt.durable, isTrue);
        final gate = SpendGateStoreDatasource.openExisting(
          spendGateStorePath(dir.path),
        );
        try {
          expect(gate.trackedInputs(bitcoin)[receipt.txid], {
            '${_b.txId}:${_b.vout}',
            '${_c.txId}:${_c.vout}',
          });
          expect(gate.isObserved(bitcoin.key, receipt.txid), isFalse);
        } finally {
          gate.close();
        }
      });
    }

    test(
      'storage retry retains the actual accepted broadcast inputs',
      () async {
        final db = sqlite3.open(spendGateStorePath(dir.path));
        addTearDown(db.close);
        db.execute(
          "CREATE TRIGGER fail_record BEFORE INSERT ON broadcasts BEGIN SELECT RAISE(FAIL, 'storage unavailable'); END",
        );
        final receipt = ok(
          await stores.spend.broadcast(
            signedForGeneration(
              key: bitcoin.key,
              generation: generation(bitcoin.key),
              transaction: SignedBitcoinTransaction(_transaction([_b, _c])),
            ),
          ),
        );
        expect(receipt.durable, isFalse);
        expect(
          await stores.spendGate.check(bitcoin.key),
          BitcoinSpendStatus.unavailable,
        );
        db.execute('DROP TRIGGER fail_record');
        expect(
          await stores.spendGate.check(bitcoin.key),
          BitcoinSpendStatus.pending,
        );
        final gate = SpendGateStoreDatasource.openExisting(
          spendGateStorePath(dir.path),
        );
        try {
          expect(gate.trackedInputs(bitcoin)[receipt.txid], {
            '${_b.txId}:${_b.vout}',
            '${_c.txId}:${_c.vout}',
          });
        } finally {
          gate.close();
        }
      },
    );

    Future<UnsignedSpend> built({
      SpendOwner? by,
      List<Outpoint>? selected,
    }) async {
      final key = bitcoin.key;
      return ok(
        await stores.spend.build(
          key,
          generation(key),
          pay(by: by, selected: selected),
        ),
      );
    }

    SignedSpend signed(UnsignedSpend unsigned) => unsigned.signed(
      SignedBitcoinTransaction(_transaction(unsigned.inputs)),
    );

    test(
      'sends once, records the spend and returns a durable receipt',
      () async {
        final receipt = ok(await stores.spend.broadcast(signed(await built())));
        expect(
          (receipt.txid, receipt.durable, receipt.guarded),
          ('d' * 64, true, true),
        );
        expect(transport.sent, hasLength(1));
      },
    );

    test('a freeze since the build refuses it unsent', () async {
      final unsigned = await built();
      ok(await stores.freezes.freeze([FrozenOutpoint(_a, origin: 'x')]));
      final failure = err(await stores.spend.broadcast(signed(unsigned)));
      expect((failure as SyncProtectedInputsFailure).frozen, {_a});
      expect(transport.sent, isEmpty);
    });

    test('a reservation since the build refuses it unsent; its owner is '
        'exempt', () async {
      final unsigned = await built();
      reservations.held = [reservation(_a, owner)];
      expect(
        err(await stores.spend.broadcast(signed(unsigned))),
        isA<SyncProtectedInputsFailure>(),
      );
      expect(transport.sent, isEmpty);

      final mine = await built(by: owner, selected: [_a]);
      ok(await stores.spend.broadcast(signed(mine)));
      expect(transport.sent, hasLength(1));
    });

    test('a stale generation is refused unsent', () async {
      final unsigned = await built();
      final key = bitcoin.key;
      revisions.begin(key, WriteIntent.delete);
      revisions.finish(key);
      revisions.begin(key, WriteIntent.create);
      revisions.finish(key, initializedDescriptor: bitcoin);
      expect(generation(key), greaterThan(unsigned.revision.generation));
      expect(
        err(await stores.spend.broadcast(signed(unsigned))),
        isA<SyncNotFoundFailure>(),
      );
      expect(transport.sent, isEmpty);
    });

    test('a receipt the guard could not record is visible', () async {
      transport.reply = const Ok('not-a-txid');
      final receipt = ok(await stores.spend.broadcast(signed(await built())));
      expect((receipt.durable, receipt.guarded), (false, true));
    });

    test('a chain failure stays a chain failure, never a refusal', () async {
      transport.reply = const Err(SyncOutcomeUnknownFailure());
      expect(
        err(await stores.spend.broadcast(signed(await built()))),
        isA<SyncOutcomeUnknownFailure>(),
      );
    });

    test('a freeze waits for the broadcast in its queue', () async {
      final unsigned = await built();
      Future<Result<PolicyRevision, SyncFailure>>? freeze;
      int? rowsWhileSending;
      transport.during = () async {
        freeze = stores.freezes.freeze([FrozenOutpoint(_a, origin: 'x')]);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        rowsWhileSending = freezes.rows.length;
      };
      ok(await stores.spend.broadcast(signed(unsigned)));
      expect(rowsWhileSending, 0);
      ok(await (freeze ?? fail('no freeze attempted')));
      expect(freezes.rows, hasLength(1));
    });

    test(
      'Liquid: freezes are checked, nothing is guarded or recorded',
      () async {
        final key = liquid.key;
        final unsigned = ok(
          await stores.spend.build(
            key,
            generation(key),
            LiquidSpendRequest(
              address: 'tlq1recipient',
              amountSat: 1000,
              fee: SpendFeeRate(100),
            ),
          ),
        );
        final receipt = ok(
          await stores.spend.broadcast(
            unsigned.signed(SignedPset(unsigned.encoded)),
          ),
        );
        expect((receipt.durable, receipt.guarded), (false, false));

        ok(await stores.freezes.freeze([FrozenOutpoint(_b, origin: 'x')]));
        expect(
          err(
            await stores.spend.broadcast(
              unsigned.signed(SignedPset(unsigned.encoded)),
            ),
          ),
          isA<SyncProtectedInputsFailure>(),
        );
        expect(transport.sent, hasLength(1));
      },
    );
  });

  group('readiness', () {
    Future<WalletValue<BitcoinSpendStatus>> published(
      WalletKey key,
      BitcoinSpendStatus status,
    ) => stores.spend
        .readiness(key)
        .watch()
        .firstWhere((value) => value.data == status)
        .timeout(const Duration(seconds: 5));

    test('closing while the guard is asked raises nothing', () async {
      final other = Directory.systemTemp.createTempSync('spend-close-');
      final closing = openForeground(
        documentsDirectory: other.path,
        catalog: _Catalog([bitcoin]),
        reservedAddresses: _Reserved(),
        freezes: MemoryFreezeStore(),
        inputReservations: _Reservations(),
        connections: FixtureConnections(const []),
        spendSessions: _Natives(),
        spendTransport: _Transport().send,
      );
      final metadata = RevisionStoreDatasource.openExisting(
        revisionStorePath(other.path),
      );
      try {
        metadata.begin(bitcoin.key, WriteIntent.create);
        metadata.finish(bitcoin.key, initializedDescriptor: bitcoin);
        // Another writer holds the wallet: the guard's request waits.
        final held = WriterLock.acquire(other.path, bitcoin.key);
        final readiness = closing.spend.readiness(bitcoin.key);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await closing.close();
        if (held case Ok(:final value)) value.release();
        await Future<void>.delayed(WriterLock.writerWaitLimit);
        expect(readiness.now.status, ValueStatus.closed);
      } finally {
        metadata.close();
        other.deleteSync(recursive: true);
      }
    });

    test('is published on first demand, without a check', () async {
      final key = bitcoin.key;
      final value = await published(key, BitcoinSpendStatus.ready);
      expect(value.revision, revisions.record(key)?.state.stamp);
      expect(stores.spend.readiness(key).now.data, BitcoinSpendStatus.ready);
    });

    test('a sync that observes the pending spend republishes it ready, '
        'without a check', () async {
      final key = bitcoin.key;
      final unsigned = ok(
        await stores.spend.build(key, generation(key), pay()),
      );
      final receipt = ok(
        await stores.spend.broadcast(
          unsigned.signed(
            SignedBitcoinTransaction(_transaction(unsigned.inputs)),
          ),
        ),
      );
      expect(stores.spend.readiness(key).now.data, BitcoinSpendStatus.pending);

      // A worker pass observes the spend and commits a revision; the
      // foreground reads it on the worker's return.
      final gate = SpendGateStoreDatasource.openExisting(
        spendGateStorePath(dir.path),
      );
      try {
        gate.observed(bitcoin, generation(key), {receipt.txid});
      } finally {
        gate.close();
      }
      revisions.begin(key, WriteIntent.sync);
      revisions.finish(key);
      final ready = published(key, BitcoinSpendStatus.ready);
      ok(await stores.revisions.read(key));
      expect((await ready).revision, revisions.record(key)?.state.stamp);
      expect(stores.spend.readiness(key).now.data, BitcoinSpendStatus.ready);
    });
  });
}
