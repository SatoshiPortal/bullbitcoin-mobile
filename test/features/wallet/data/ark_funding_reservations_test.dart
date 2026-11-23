import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bull_ark/ark_wallet_setup.dart';
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

// Public generator point and synthetic DER-shaped r/s, from Sync codec tests.
// Signature PRESENCE only; neither fixture proves a cryptographically valid sig.
String withPartial(String encoded) {
  const pubkey =
      '0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
  final key = [
    2,
    for (var i = 0; i < pubkey.length; i += 2)
      int.parse(pubkey.substring(i, i + 2), radix: 16),
  ];
  final signature = [
    0x30,
    0x44,
    2,
    0x20,
    ...List.filled(32, 1),
    2,
    0x20,
    ...List.filled(32, 2),
    1,
  ];
  final bytes = base64Decode(encoded);
  return base64Encode([
    ...bytes.take(bytes.length - 2),
    key.length,
    ...key,
    signature.length,
    ...signature,
    0,
    0,
  ]);
}

// Two independent SQLite connections/isolate lifetimes. No native wallet or keys.
Future<void> raceAuthority((String, bool, SendPort) args) async {
  final (path, seal, parent) = args;
  final control = ReceivePort();
  SqliteArkFundingReservations? connection;
  parent.send(['control', seal, control.sendPort]);
  try {
    final opened = ok(
      SqliteArkFundingReservations.open(path, foreground: false),
    );
    connection = opened;
    final binding = ok(await opened.readBinding('op'));
    parent.send(['ready', seal]);
    final command = await control.first;
    if (command == 'go') {
      final result = seal
          ? await opened.beginSigning(
              expected: binding,
              admittedRevision: binding.revision,
            )
          : await opened.tombstoneNeverSigned(
              expected: binding,
              admittedRevision: binding.revision,
            );
      parent.send(['done', seal, result is Ok]);
    }
  } on Exception catch (failure) {
    parent.send(['failed', seal, failure.runtimeType.toString()]);
  } finally {
    connection?.close();
    control.close();
  }
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
  Future<void> legacyTerminal() async {
    ok(await begin('legacy'));
    ok(
      await store.reserve(
        key: key,
        spend: spend('legacy'),
        context: 'public-context',
      ),
    );
    final db = sqlite3.open('${dir.path}/store');
    try {
      db.execute("UPDATE ark_funding_operations SET state='confirmed'");
      db.execute('DELETE FROM ark_funding_inputs');
      if (db
          .select(
            "SELECT 1 FROM sqlite_master WHERE name='ark_funding_authority'",
          )
          .isNotEmpty) {
        db.execute('DELETE FROM ark_funding_authority');
      }
    } finally {
      db.close();
    }
  }

  test('signatures require an irreversible signing-start seal', () async {
    ok(await begin('op'));
    ok(
      await store.reserve(
        key: key,
        spend: spend('op'),
        context: 'public-context',
      ),
    );
    expect(await store.recordSigned('op', withWitness(psbt)), isA<Err>());
  });
  test(
    'terminal legacy operation cannot be reopened by identical begin',
    () async {
      await legacyTerminal();
      expect(await begin('legacy'), isA<Err>());
    },
  );
  test(
    'terminal transaction cannot be reauthorized under a different owner',
    () async {
      await legacyTerminal();
      ok(await begin('new-owner'));
      expect(
        await store.reserve(
          key: key,
          spend: spend('new-owner'),
          context: 'public-context',
        ),
        isA<Err>(),
      );
    },
  );
  test(
    'legacy terminal label alone cannot retire its source seed pin',
    () async {
      await legacyTerminal();
      final refs = await store.getCustodyFingerprints();
      expect(
        refs,
        isA<Ok<Set<Fingerprint>, Failure>>().having(
          (r) => r.value,
          'unproven source parents',
          {parent},
        ),
      );
    },
  );
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
        admittedRevision: stamp(revision: 3),
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
        admittedRevision: stamp(revision: 3),
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
        admittedRevision: stamp(revision: 3),
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
        admittedRevision: stamp(revision: 3),
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
    ok(
      await store.beginSigning(
        expected: ok(await store.readBinding('op')),
        admittedRevision: stamp(),
      ),
    );
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
        admittedRevision: stamp(revision: 3),
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
        admittedRevision: stamp(revision: 3),
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
        admittedRevision: stamp(revision: 3),
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
  Future<ArkFundingBinding> prepared({String encoded = psbt}) async {
    ok(await begin('op'));
    ok(
      await store.reserve(
        key: key,
        spend: spend('op', encoded: encoded),
        context: 'public-context',
      ),
    );
    return ok(await store.readBinding('op'));
  }

  Future<Set<Fingerprint>> pins() async {
    return switch (await store.getCustodyFingerprints()) {
      Ok(:final value) => value,
      Err(:final failure) => throw StateError(
        'Unexpected ${failure.runtimeType}',
      ),
    };
  }

  void edit(String sql, [List<Object?> parameters = const []]) {
    final db = sqlite3.open('${dir.path}/store');
    try {
      db.execute(sql, parameters);
    } finally {
      db.close();
    }
  }

  ArkFundingBinding changed(ArkFundingBinding b, String field) {
    final otherKey = WalletKey(id: 'alias', network: BitcoinNetwork.regtest);
    return ArkFundingBinding(
      operationId: field == 'operation' ? 'another' : b.operationId,
      accountIdentity: field == 'account' ? 'another' : b.accountIdentity,
      sourceParent: field == 'parent'
          ? Fingerprint('aabbccdd')
          : b.sourceParent,
      key: field == 'key' ? otherKey : b.key,
      revision: WalletRevision(
        key: field == 'revisionKey' ? otherKey : b.key,
        generation: field == 'generation' ? 2 : b.revision.generation,
        revision: field == 'revision' ? 99 : b.revision.revision,
      ),
      context: field == 'context' ? 'changed' : b.context,
      unsignedPsbt: field == 'psbt'
          ? twoInputPsbt(outputSat: 99999)
          : b.unsignedPsbt,
      unsignedTxid: field == 'txid'
          ? List.filled(64, 'a').join()
          : b.unsignedTxid,
      inputs: field == 'inputs' ? b.inputs.reversed.toList() : b.inputs,
    );
  }

  test('seal is durable and cannot become never-signed after reopen', () async {
    final binding = await prepared();
    ok(await store.beginSigning(expected: binding, admittedRevision: stamp()));
    store.close();
    store = ok(
      SqliteArkFundingReservations.open('${dir.path}/store', foreground: false),
    );
    ok(
      await store.beginSigning(
        expected: binding,
        admittedRevision: stamp(revision: 3),
      ),
    );
    expect(
      await store.tombstoneNeverSigned(
        expected: binding,
        admittedRevision: stamp(),
      ),
      isA<Err>(),
    );
    expect(ok(await store.reservations()).length, 1);
    expect(await pins(), {parent});
  });
  test(
    'tombstone is durable idempotent and ends only its source pin',
    () async {
      final binding = await prepared();
      ok(
        await store.tombstoneNeverSigned(
          expected: binding,
          admittedRevision: stamp(),
        ),
      );
      store.close();
      store = ok(
        SqliteArkFundingReservations.open(
          '${dir.path}/store',
          foreground: false,
        ),
      );
      ok(
        await store.tombstoneNeverSigned(
          expected: binding,
          admittedRevision: stamp(),
        ),
      );
      expect(
        await store.beginSigning(expected: binding, admittedRevision: stamp()),
        isA<Err>(),
      );
      expect(await store.recordSigned('op', withWitness(psbt)), isA<Err>());
      expect(await begin('op'), isA<Err>());
      expect(
        await store.reserve(
          key: key,
          spend: spend('op'),
          context: 'public-context',
        ),
        isA<Err>(),
      );
      expect(ok(await store.reservations()), isEmpty);
      expect(await pins(), isEmpty);
      final retained = ok(await store.readBinding('op'));
      expect(retained.unsignedPsbt, psbt);
      expect(retained.sourceParent, parent);
      ok(await begin('other-obligation'));
      expect(await pins(), {parent});
    },
  );
  for (final field in [
    'operation',
    'account',
    'parent',
    'key',
    'generation',
    'revision',
    'revisionKey',
    'context',
    'psbt',
    'txid',
    'inputs',
  ]) {
    test('CAS refuses exact immutable binding mismatch $field', () async {
      final binding = await prepared(encoded: twoInputPsbt());
      final wrong = changed(binding, field);
      expect(
        await store.beginSigning(expected: wrong, admittedRevision: stamp()),
        isA<Err>(),
      );
      expect(
        await store.tombstoneNeverSigned(
          expected: wrong,
          admittedRevision: stamp(),
        ),
        isA<Err>(),
      );
      expect(ok(await store.reservations()).length, 2);
      expect(await pins(), {parent});
    });
  }
  test(
    'CAS refuses wrong current admission without changing ownership',
    () async {
      final binding = await prepared();
      for (final revision in [
        stamp(generation: 2),
        stamp(revision: 1),
        WalletRevision(
          key: WalletKey(id: 'alias', network: BitcoinNetwork.regtest),
          generation: 1,
          revision: 2,
        ),
      ]) {
        expect(
          await store.beginSigning(
            expected: binding,
            admittedRevision: revision,
          ),
          isA<Err>(),
        );
        expect(
          await store.tombstoneNeverSigned(
            expected: binding,
            admittedRevision: revision,
          ),
          isA<Err>(),
        );
      }
      expect(ok(await store.reservations()).length, 1);
    },
  );
  test('classification is network-wide and validates missing ownership before negative lookup', () async {
    final binding = await prepared(encoded: twoInputPsbt());
    expect(
      ok(
        await store.bindingForSigning(
          key: key,
          unsignedPsbt: binding.unsignedPsbt,
        ),
      )?.operationId,
      'op',
    );
    final alias = WalletKey(id: 'alias', network: BitcoinNetwork.regtest);
    expect(
      await store.bindingForSigning(
        key: alias,
        unsignedPsbt: binding.unsignedPsbt,
      ),
      isA<Err>(),
    );
    final overlap = twoInputPsbt(inputBytes: [0x11], outputSat: 50000);
    expect(
      await store.bindingForSigning(key: alias, unsignedPsbt: overlap),
      isA<Err>(),
    );
    final unrelated = twoInputPsbt(inputBytes: [0x44], outputSat: 50000);
    expect(
      ok(await store.bindingForSigning(key: alias, unsignedPsbt: unrelated)),
      isNull,
    );
    edit('DELETE FROM ark_funding_inputs WHERE txid=?', [
      binding.inputs.first.txId,
    ]);
    expect(
      await store.bindingForSigning(key: alias, unsignedPsbt: overlap),
      isA<Err>(),
    );
    expect(
      await store.bindingForSigning(key: alias, unsignedPsbt: unrelated),
      isA<Err>(),
    );
  });
  test(
    'terminal txid classification refuses an alias even without active inputs',
    () async {
      final binding = await prepared();
      ok(
        await store.tombstoneNeverSigned(
          expected: binding,
          admittedRevision: stamp(),
        ),
      );
      expect(
        await store.bindingForSigning(
          key: WalletKey(id: 'alias', network: key.network),
          unsignedPsbt: psbt,
        ),
        isA<Err>(),
      );
    },
  );
  test(
    'legacy active rows remain held and cannot acquire a retrospective seal',
    () async {
      final binding = await prepared();
      edit('DELETE FROM ark_funding_authority');
      ok(await begin('op'));
      expect(
        await store.beginSigning(expected: binding, admittedRevision: stamp()),
        isA<Err>(),
      );
      expect(
        await store.tombstoneNeverSigned(
          expected: binding,
          admittedRevision: stamp(),
        ),
        isA<Err>(),
      );
      expect(ok(await store.reservations()).length, 1);
      expect(await pins(), {parent});
    },
  );
  test('fresh admitted positive history certifies a legacy terminal source closure', () async {
    await legacyTerminal();
    final binding = ok(await store.readBinding('legacy'));
    BitcoinTransaction tx() => BitcoinTransaction(
      txid: binding.unsignedTxid,
      feeSat: 200,
      vsize: 100,
      confirmationTime: 1700000000,
      inputs: [],
      outputs: [],
      sentSat: 100200,
      receivedSat: 0,
      isExplicitlyRbf: false,
    );
    final history = WalletTransactions.ready(
      ChainTransactionList([tx()]),
      stamp(revision: 3),
    );
    expect(
      await store.observe(key, history, admittedRevision: stamp(revision: 4)),
      isA<Err>(),
    );
    expect(await pins(), {parent});
    ok(await store.observe(key, history, admittedRevision: stamp(revision: 3)));
    expect(await pins(), isEmpty);
    expect(ok(await store.reservations()), isEmpty);
    expect(ok(await store.readBinding('legacy')).unsignedPsbt, psbt);
    final db = sqlite3.open('${dir.path}/store');
    try {
      expect(
        db
            .select('SELECT signing FROM ark_funding_authority')
            .single['signing'],
        'unknown',
      );
    } finally {
      db.close();
    }
  });
  test(
    'failed seal and tombstone input deletion roll back all ownership changes',
    () async {
      final binding = await prepared();
      edit(
        "CREATE TRIGGER fail_seal BEFORE UPDATE ON ark_funding_authority BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      expect(
        await store.beginSigning(expected: binding, admittedRevision: stamp()),
        isA<Err>(),
      );
      edit('DROP TRIGGER fail_seal');
      edit(
        "CREATE TRIGGER fail_release BEFORE DELETE ON ark_funding_inputs BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      expect(
        await store.tombstoneNeverSigned(
          expected: binding,
          admittedRevision: stamp(),
        ),
        isA<Err>(),
      );
      expect(ok(await store.reservations()).length, 1);
      expect(await pins(), {parent});
      edit('DROP TRIGGER fail_release');
      ok(
        await store.beginSigning(expected: binding, admittedRevision: stamp()),
      );
    },
  );
  for (final field in [
    'version',
    'kind',
    'closed',
    'binding',
    'admitted',
    'observedTxid',
    'confirmationTime',
    'matchedInput',
  ]) {
    test(
      'corrupt closure $field never retires a source pin as empty inventory',
      () async {
        final binding = await prepared();
        ok(
          await store.tombstoneNeverSigned(
            expected: binding,
            admittedRevision: stamp(),
          ),
        );
        final db = sqlite3.open('${dir.path}/store');
        try {
          final proof = jsonDecode(
            db
                    .select('SELECT settlement FROM ark_funding_authority')
                    .single['settlement']
                as String,
          ) as Map<String, dynamic>;
          proof[field] = switch (field) {
            'version' => 2,
            'kind' => 'unknown',
            'closed' => false,
            'binding' || 'admitted' => <String, dynamic>{},
            'observedTxid' => binding.unsignedTxid,
            'confirmationTime' => 1700000000,
            _ => [binding.inputs.first.txId, 0],
          };
          db.execute('UPDATE ark_funding_authority SET settlement=?', [
            jsonEncode(proof),
          ]);
        } finally {
          db.close();
        }
        expect(await store.getCustodyFingerprints(), isA<Err>());
        expect(await store.reservations(), isA<Err>());
        expect(
          await store.tombstoneNeverSigned(
            expected: binding,
            admittedRevision: stamp(),
          ),
          isA<Err>(),
        );
      },
    );
  }
  test(
    'BEGIN IMMEDIATE contention refuses without partial seal or release',
    () async {
      final binding = await prepared();
      final blocker = sqlite3.open('${dir.path}/store');
      try {
        blocker.execute('BEGIN IMMEDIATE');
        expect(
          await store.beginSigning(
            expected: binding,
            admittedRevision: stamp(),
          ),
          isA<Err>(),
        );
        expect(
          await store.tombstoneNeverSigned(
            expected: binding,
            admittedRevision: stamp(),
          ),
          isA<Err>(),
        );
      } finally {
        blocker.execute('ROLLBACK');
        blocker.close();
      }
      expect(ok(await store.reservations()).length, 1);
      ok(
        await store.tombstoneNeverSigned(
          expected: binding,
          admittedRevision: stamp(),
        ),
      );
    },
  );
  test('real independent isolates race seal against tombstone with exactly one winner', () async {
    await prepared();
    final messages = ReceivePort();
    final exits = [ReceivePort(), ReceivePort()];
    final stream = StreamIterator<dynamic>(messages);
    final controls = <SendPort>[];
    final wins = <bool>[];
    await Isolate.spawn(
      raceAuthority,
      ('${dir.path}/store', true, messages.sendPort),
      onExit: exits[0].sendPort,
      onError: messages.sendPort,
    );
    await Isolate.spawn(
      raceAuthority,
      ('${dir.path}/store', false, messages.sendPort),
      onExit: exits[1].sendPort,
      onError: messages.sendPort,
    );
    try {
      var ready = 0;
      var failed = false;
      while (controls.length < 2 || (ready < 2 && !failed)) {
        expect(await stream.moveNext(), true);
        final event = stream.current as List;
        if (event[0] == 'control') {
          controls.add(event[2] as SendPort);
        } else if (event[0] == 'ready') {
          ready++;
        } else {
          failed = true; // Report worker failure without exposing foreign text.
        }
      }
      expect(failed, false, reason: 'A race worker could not initialize');
      for (final control in controls) {
        control.send('go');
      }
      while (wins.length < 2) {
        expect(await stream.moveNext(), true);
        final event = stream.current as List;
        expect(event[0], 'done');
        wins.add(event[2] as bool);
      }
      expect(wins.where((w) => w).length, 1);
    } finally {
      for (final control in controls) {
        control.send('stop');
      }
      await Future.wait(exits.map((port) => port.first));
      for (final exit in exits) {
        exit.close();
      }
      await stream.cancel();
      messages.close();
    }
    store.close();
    store = ok(
      SqliteArkFundingReservations.open('${dir.path}/store', foreground: false),
    );
    final binding = ok(await store.readBinding('op'));
    final held = ok(await store.reservations());
    expect(held.length, anyOf(0, 1));
    final result = held.isEmpty
        ? await store.beginSigning(expected: binding, admittedRevision: stamp())
        : await store.tombstoneNeverSigned(
            expected: binding,
            admittedRevision: stamp(),
          );
    expect(result, isA<Err>());
  });
  for (final column in ['txid', 'vout']) {
    test(
      'bad SQLite reservation runtime kind $column is a typed refusal',
      () async {
        await prepared();
        edit('UPDATE ark_funding_inputs SET $column=?', [
          column == 'txid' ? Uint8List.fromList([1, 2, 3]) : 0.5,
        ]);
        expect(await store.reservations(), isA<Err>());
        expect(await store.getCustodyFingerprints(), isA<Err>());
        expect(
          await store.bindingForSigning(
            key: key,
            unsignedPsbt: twoInputPsbt(inputBytes: [0x44], outputSat: 50000),
          ),
          isA<Err>(),
        );
      },
    );
  }
  group('persisted original prepared facts and authority schema', () {
    Future<ArkFundingBinding> prepare() async {
      ok(
        await store.begin(
          operationId: 'f1',
          accountIdentity: 'public-fixture',
          sourceParent: Fingerprint('00112233'),
          key: key,
          generation: 1,
          context: 'public-f1-context',
        ),
      );
      ok(
        await store.reserve(
          key: key,
          context: 'public-f1-context',
          spend: UnsignedSpend(
            revision: stamp(),
            encoded: psbt,
            inputs: decodeBitcoinPsbt(psbt).inputs,
            owner: SpendOwner(protocol: 'ark', session: 'f1'),
          ),
        ),
      );
      return ok(await store.readBinding('f1'));
    }

    void mutateOriginal(String encoded) {
      final db = sqlite3.open('${dir.path}/store');
      try {
        db.execute('UPDATE ark_funding_operations SET psbt=?', [encoded]);
      } finally {
        db.close();
      }
    }

    for (final kind in ['finalWitness', 'partialSignature']) {
      for (final api in [
        'readBinding',
        'inventory',
        'pins',
        'classifier',
        'tombstone',
      ]) {
        test('F1 signed original $kind refuses $api without release', () async {
          final original = await prepare();
          final encoded = kind == 'finalWitness'
              ? withWitness(psbt)
              : withPartial(psbt);
          final facts = ok(inspectBitcoinPsbt(encoded));
          expect(facts.unsignedTxid, original.unsignedTxid);
          expect(decodeBitcoinPsbt(encoded).txid, original.unsignedTxid);
          expect(
            kind == 'finalWitness'
                ? facts.inputs.single.hasFinalFields
                : facts.inputs.single.hasPartialSignatures,
            isTrue,
          );
          mutateOriginal(encoded);
          final tampered = ArkFundingBinding(
            operationId: original.operationId,
            accountIdentity: original.accountIdentity,
            sourceParent: original.sourceParent,
            key: original.key,
            revision: original.revision,
            context: original.context,
            unsignedPsbt: encoded,
            unsignedTxid: original.unsignedTxid,
            inputs: original.inputs,
          );
          final Result<dynamic, Failure> result;
          switch (api) {
            case 'readBinding':
              result = await store.readBinding('f1');
            case 'inventory':
              result = await store.reservations();
            case 'pins':
              result = await store.getCustodyFingerprints();
            case 'classifier':
              result = await store.bindingForSigning(
                key: key,
                unsignedPsbt: twoInputPsbt(
                  inputBytes: [0x44],
                  outputSat: 50000,
                ),
              );
            case 'tombstone':
              result = await store.tombstoneNeverSigned(
                expected: tampered,
                admittedRevision: stamp(),
              );
            default:
              throw StateError('Unknown fixture API');
          }
          expect(result, isA<Err<dynamic, Failure>>());
          final db = sqlite3.open('${dir.path}/store');
          try {
            expect(
              db
                  .select('SELECT COUNT(*) AS n FROM ark_funding_inputs')
                  .single['n'],
              1,
            );
            expect(
              db
                  .select('SELECT settlement FROM ark_funding_authority')
                  .single['settlement'],
              isNull,
            );
            expect(
              db
                  .select('SELECT signed_psbt FROM ark_funding_operations')
                  .single['signed_psbt'],
              isNull,
            );
          } finally {
            db.close();
          }
        });
      }
    }

    test('missing authority table refuses without resetting operations', () async {
      await prepare();
      store.close();
      final db = sqlite3.open('${dir.path}/store');
      try {
        db.execute('DROP TABLE ark_funding_authority');
        for (final foreground in [false, true]) {
          for (final initializeNew in [false, true]) {
            expect(
              SqliteArkFundingReservations.open(
                '${dir.path}/store',
                foreground: foreground,
                initializeNew: initializeNew,
              ),
              isA<Err>(),
            );
          }
        }
        expect(db.select('SELECT * FROM ark_funding_operations'), hasLength(1));
        expect(
          db.select(
            "SELECT name FROM sqlite_master WHERE name='ark_funding_authority'",
          ),
          isEmpty,
        );
      } finally {
        db.close();
      }
    });

    test(
      'incompatible authority schema refuses without resetting operations',
      () async {
        await prepare();
        store.close();
        final db = sqlite3.open('${dir.path}/store');
        try {
          db.execute('DROP TABLE ark_funding_authority');
          db.execute(
            'CREATE TABLE ark_funding_authority(operation TEXT PRIMARY KEY,protocol TEXT NOT NULL,signing TEXT NOT NULL,settlement TEXT)',
          );
        } finally {
          db.close();
        }
        expect(
          SqliteArkFundingReservations.open(
            '${dir.path}/store',
            foreground: false,
          ),
          isA<Err>(),
        );
        expect(
          SqliteArkFundingReservations.open(
            '${dir.path}/store',
            foreground: true,
          ),
          isA<Err>(),
        );
        final retained = sqlite3.open(
          '${dir.path}/store',
          mode: OpenMode.readOnly,
        );
        try {
          expect(
            retained
                .select('SELECT psbt FROM ark_funding_operations')
                .single['psbt'],
            psbt,
          );
        } finally {
          retained.close();
        }
      },
    );
  });
}
