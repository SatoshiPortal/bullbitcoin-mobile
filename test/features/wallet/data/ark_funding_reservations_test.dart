import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/features/wallet/data/sqlite_ark_funding_reservations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sync/sync.dart';

// Synthetic public PSBT: one input100200sat, one output100000sat. No keys.
const psbt =
    'cHNidP8BAFICAAAAAQECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gAAAAAAD9////'
    'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
    'MzMzMzMzMzMzMzMzMzMzMzMAAA==';
T ok<T>(Result<T, SyncFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError('Unexpected ${failure.runtimeType}'),
};
String withWitness(String encoded, {int witness = 0x42}) {
  final bytes = base64Decode(encoded);
  return base64Encode([
    ...bytes.take(bytes.length - 2),
    1,
    8,
    3,
    1,
    1,
    witness,
    0,
    0,
  ]);
}

String twoInputPsbt({
  List<int> inputBytes = const [0x11, 0x22],
  int outputSat = 100000,
}) {
  final script = [0, 20, ...List.filled(20, 0x22)];
  List<int> sats(int value) => [
    for (var i = 0; i < 8; i++) (value >> (8 * i)) & 255,
  ];
  final unsigned = [
    2,
    0,
    0,
    0,
    inputBytes.length,
    for (final byte in inputBytes) ...[
      ...List.filled(32, byte),
      0,
      0,
      0,
      0,
      0,
      0xfd,
      0xff,
      0xff,
      0xff,
    ],
    1,
    ...sats(outputSat),
    script.length,
    ...script,
    0,
    0,
    0,
    0,
  ];
  return base64Encode([
    0x70,
    0x73,
    0x62,
    0x74,
    0xff,
    1,
    0,
    unsigned.length,
    ...unsigned,
    0,
    for (var input = 0; input < inputBytes.length; input++) ...[
      1,
      1,
      8 + 1 + script.length,
      ...sats(60000),
      script.length,
      ...script,
      0,
    ],
    0,
  ]);
}

void main() {
  late Directory dir;
  late SqliteArkFundingReservations store;
  final key = WalletKey(id: 'source-wallet', network: BitcoinNetwork.regtest);
  final parent = Fingerprint('00112233');
  WalletRevision stamp({int generation = 1, int revision = 2}) =>
      WalletRevision(key: key, generation: generation, revision: revision);
  UnsignedSpend spend(
    String operation, {
    String encoded = psbt,
    int generation = 1,
  }) => UnsignedSpend(
    revision: stamp(generation: generation),
    encoded: encoded,
    inputs: decodeBitcoinPsbt(encoded).inputs,
    owner: SpendOwner(protocol: 'ark', session: operation),
  );
  Future<Result<void, SyncFailure>> begin(
    String operation, {
    String context = 'public-context',
    int generation = 1,
  }) => store.begin(
    operationId: operation,
    accountIdentity: 'ark-account',
    sourceParent: parent,
    key: key,
    generation: generation,
    context: context,
  );
  setUp(() {
    dir = Directory.systemTemp.createTempSync('ark-funding-');
    store = ok(
      SqliteArkFundingReservations.open(
        '${dir.path}/store',
        foreground: true,
        initializeNew: true,
      ),
    );
  });
  tearDown(() {
    store.close();
    dir.deleteSync(recursive: true);
  });
  test('existing-only missing store fails without creating a file', () {
    final path = '${dir.path}/missing';
    expect(
      SqliteArkFundingReservations.open(path, foreground: false),
      isA<Err>(),
    );
    expect(File(path).existsSync(), false);
  });
  test('reserve requires prior request and preserves exact idempotent holding across reopen', () async {
    expect(
      await store.reserve(
        key: key,
        spend: spend('op'),
        context: 'public-context',
      ),
      isA<Err>(),
    );
    expect(await begin('op'), isA<Ok>());
    expect(
      await store.reserve(
        key: key,
        spend: spend('op'),
        context: 'public-context',
      ),
      isA<Ok>(),
    );
    expect(
      await store.reserve(
        key: key,
        spend: spend('op'),
        context: 'public-context',
      ),
      isA<Ok>(),
    );
    expect(ok(await store.reservations()).length, 1);
    store.close();
    store = ok(
      SqliteArkFundingReservations.open('${dir.path}/store', foreground: false),
    );
    expect(ok(await store.reservations()).single.session, 'op');
    final custody = await store.getCustodyFingerprints();
    expect(
      custody,
      isA<Ok<Set<Fingerprint>, Failure>>().having((r) => r.value, 'parents', {
        parent,
      }),
    );
    final db = sqlite3.open('${dir.path}/store');
    final row = db.select('SELECT * FROM ark_funding_operations').single;
    expect(row['psbt'], psbt);
    expect(row['txid'], decodeBitcoinPsbt(psbt).txid);
    expect(row['context'], 'public-context');
    db.close();
  });
  test(
    'changed context generation or source cannot reuse an operation',
    () async {
      await begin('op');
      await store.reserve(
        key: key,
        spend: spend('op'),
        context: 'public-context',
      );
      expect(await begin('op', context: 'changed'), isA<Err>());
      expect(await begin('op', generation: 2), isA<Err>());
      expect(
        await store.reserve(
          key: key,
          spend: spend('op', generation: 2),
          context: 'public-context',
        ),
        isA<Err>(),
      );
      expect(
        await store.reserve(key: key, spend: spend('op'), context: 'changed'),
        isA<Err>(),
      );
      expect(ok(await store.reservations()).length, 1);
    },
  );
  test('overlapping operation cannot take effective input ownership', () async {
    await begin('first');
    await begin('second');
    await store.reserve(
      key: key,
      spend: spend('first'),
      context: 'public-context',
    );
    expect(
      await store.reserve(
        key: key,
        spend: spend('second'),
        context: 'public-context',
      ),
      isA<Err>(),
    );
    expect(ok(await store.reservations()).single.session, 'first');
  });
  test(
    'failed input persistence rolls back operation and every reservation',
    () async {
      await begin('op');
      final db = sqlite3.open('${dir.path}/store');
      db.execute(
        "CREATE TRIGGER fail_input BEFORE INSERT ON ark_funding_inputs BEGIN SELECT RAISE(ABORT,'test');END",
      );
      expect(
        await store.reserve(
          key: key,
          spend: spend('op'),
          context: 'public-context',
        ),
        isA<Err>(),
      );
      expect(ok(await store.reservations()), isEmpty);
      expect(
        db
            .select('SELECT state,psbt FROM ark_funding_operations')
            .single['state'],
        'requested',
      );
      expect(
        db
            .select('SELECT state,psbt FROM ark_funding_operations')
            .single['psbt'],
        isNull,
      );
      db.close();
    },
  );
  test(
    'missing persisted ownership is an unreadable inventory, never empty',
    () async {
      await begin('op');
      await store.reserve(
        key: key,
        spend: spend('op'),
        context: 'public-context',
      );
      final db = sqlite3.open('${dir.path}/store');
      db.execute('DELETE FROM ark_funding_inputs');
      db.close();
      expect(await store.reservations(), isA<Err>());
    },
  );
  test(
    'partially missing ownership cannot expose the surviving input as complete',
    () async {
      final encoded = twoInputPsbt();
      await begin('multi');
      expect(
        await store.reserve(
          key: key,
          spend: spend('multi', encoded: encoded),
          context: 'public-context',
        ),
        isA<Ok>(),
      );
      expect(ok(await store.reservations()).length, 2);
      final db = sqlite3.open('${dir.path}/store');
      db.execute('DELETE FROM ark_funding_inputs WHERE txid=?', [
        decodeBitcoinPsbt(encoded).inputs.first.txId,
      ]);
      db.close();
      expect(await store.reservations(), isA<Err>());
    },
  );
  test('absence unconfirmed or stale history never releases; confirmed exact tx does', () async {
    await begin('op');
    await store.reserve(
      key: key,
      spend: spend('op'),
      context: 'public-context',
    );
    expect(
      await store.observe(
        key,
        WalletTransactions.ready(ChainTransactionList([]), stamp(revision: 3)),
      ),
      isA<Ok>(),
    );
    expect(ok(await store.reservations()).length, 1);
    final decoded = decodeBitcoinPsbt(psbt);
    BitcoinTransaction tx(int? confirmed) => BitcoinTransaction(
      txid: decoded.txid,
      feeSat: 200,
      vsize: decoded.vsize,
      confirmationTime: confirmed,
      inputs: [],
      outputs: [],
      sentSat: 100200,
      receivedSat: 0,
      isExplicitlyRbf: false,
    );
    expect(
      await store.observe(
        key,
        WalletTransactions.ready(
          ChainTransactionList([tx(null)]),
          stamp(revision: 3),
        ),
      ),
      isA<Ok>(),
    );
    expect(ok(await store.reservations()).length, 1);
    expect(
      await store.observe(
        key,
        WalletTransactions.stale(
          ChainTransactionList([tx(1700000000)]),
          stamp(revision: 3),
        ),
      ),
      isA<Err>(),
    );
    expect(ok(await store.reservations()).length, 1);
    expect(
      await store.observe(
        key,
        WalletTransactions.ready(
          ChainTransactionList([tx(1700000000)]),
          stamp(revision: 3),
        ),
      ),
      isA<Ok>(),
    );
    expect(ok(await store.reservations()), isEmpty);
    final db = sqlite3.open('${dir.path}/store');
    expect(
      db.select('SELECT psbt FROM ark_funding_operations').single['psbt'],
      psbt,
    );
    db.close();
  });
  test(
    'missing initialized funding metadata cannot be silently recreated',
    () async {
      await begin('op');
      await store.reserve(
        key: key,
        spend: spend('op'),
        context: 'public-context',
      );
      store.close();
      File('${dir.path}/store').deleteSync();
      final reopened = SqliteArkFundingReservations.open(
        '${dir.path}/store',
        foreground: true,
        initializeNew: true,
      );
      if (reopened case Ok(:final value)) value.close();
      expect(reopened, isA<Err>());
    },
  );
  test(
    'prepared boundary rejects any signed PSBT even before final handoff',
    () async {
      await begin('op');
      expect(
        await store.reserve(
          key: key,
          spend: spend('op', encoded: withWitness(psbt)),
          context: 'public-context',
        ),
        isA<Err>(),
      );
      expect(ok(await store.reservations()), isEmpty);
    },
  );
  test('signature journal retains exact bytes, original fee and actual finalisation', () async {
    await begin('op');
    await store.reserve(
      key: key,
      spend: spend('op'),
      context: 'public-context',
    );
    expect(await store.recordSigned('op', psbt), isA<Err>());
    final signed = withWitness(psbt);
    final tampered = base64Decode(signed);
    final offset = List.generate(tampered.length - 2, (i) => i).firstWhere(
      (i) =>
          tampered[i] == 0x68 &&
          tampered[i + 1] == 0x87 &&
          tampered[i + 2] == 1,
    );
    tampered[offset] = 0x69;
    expect(
      decodeBitcoinPsbt(base64Encode(tampered)).txid,
      decodeBitcoinPsbt(signed).txid,
    );
    expect(await store.recordSigned('op', base64Encode(tampered)), isA<Err>());
    expect(await store.recordSigned('op', signed), isA<Ok>());
    expect(await store.recordSigned('op', signed), isA<Ok>());
    expect(
      await store.recordSigned('op', withWitness(psbt, witness: 0x43)),
      isA<Err>(),
    );
    expect(ok(await store.reservations()).length, 1);
  });
  test('initialized marker never permits version-zero funding reset even with initializeNew', () async {
    await begin('op');
    await store.reserve(
      key: key,
      spend: spend('op'),
      context: 'public-context',
    );
    store.close();
    File('${dir.path}/store').writeAsBytesSync([], flush: true);
    final reset = SqliteArkFundingReservations.open(
      '${dir.path}/store',
      foreground: true,
      initializeNew: true,
    );
    if (reset case Ok(:final value)) value.close();
    expect(reset, isA<Err>());
  });
  test('confirmed conflict settles active holds so unused B can fund a new operation', () async {
    final original = twoInputPsbt();
    final originalSpend = spend('original', encoded: original);
    await begin('original');
    expect(
      await store.reserve(
        key: key,
        spend: originalSpend,
        context: 'public-context',
      ),
      isA<Ok>(),
    );
    BitcoinTransaction conflict(int? confirmed) => BitcoinTransaction(
      txid: List.filled(32, '55').join(),
      feeSat: 100,
      vsize: 100,
      confirmationTime: confirmed,
      inputs: [
        BitcoinInput(
          previousOutput: originalSpend.inputs.first,
          scriptSig: Uint8List(0),
        ),
      ],
      outputs: [],
      sentSat: 60000,
      receivedSat: 0,
      isExplicitlyRbf: false,
    );
    expect(
      await store.observe(
        key,
        WalletTransactions.ready(
          ChainTransactionList([conflict(null)]),
          stamp(revision: 3),
        ),
      ),
      isA<Ok>(),
    );
    expect(ok(await store.reservations()).length, 2);
    expect(
      await store.observe(
        key,
        WalletTransactions.stale(
          ChainTransactionList([conflict(1700000000)]),
          stamp(revision: 3),
        ),
      ),
      isA<Err>(),
    );
    expect(ok(await store.reservations()).length, 2);
    expect(
      await store.observe(
        key,
        WalletTransactions.ready(
          ChainTransactionList([conflict(1700000000)]),
          stamp(revision: 3),
        ),
      ),
      isA<Ok>(),
    );
    expect(ok(await store.reservations()), isEmpty);
    final db = sqlite3.open('${dir.path}/store');
    final evidence = db
        .select(
          "SELECT * FROM ark_funding_operations WHERE operation='original'",
        )
        .single;
    expect(evidence['state'], 'conflicted');
    expect(evidence['psbt'], original);
    expect(evidence['txid'], decodeBitcoinPsbt(original).txid);
    db.close();
    await begin('next');
    final onlyB = twoInputPsbt(inputBytes: [0x22], outputSat: 50000);
    expect(
      await store.reserve(
        key: key,
        spend: spend('next', encoded: onlyB),
        context: 'public-context',
      ),
      isA<Ok>(),
    );
    expect(ok(await store.reservations()).single.session, 'next');
  });
}
