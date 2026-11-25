import 'dart:convert';
import 'dart:io';

import 'package:bull_ark/ark_wallet_setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

const psbt =
    'cHNidP8BAFICAAAAAQECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gAAAAAAD9////'
    'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
    'MzMzMzMzMzMzMzMzMzMzMzMAAA==';

T ok<T>(Result<T, SyncFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError('${failure.runtimeType}'),
};

void main() {
  late Directory directory;
  late SqliteArkFundingReservations store;
  final key = WalletKey(id: 'source', network: BitcoinNetwork.regtest);
  final parent = Fingerprint('00112233');
  final context = jsonEncode({
    'version': 1,
    'type': 'exitReserve',
    'account': 'account',
    'ids': ['vtxo'],
    'destination': 'destination',
    'reserveAddress': 'reserve',
    'sats': '100000',
    'chainSource': 'https://example.test',
  });
  WalletRevision stamp(int revision) =>
      WalletRevision(key: key, generation: 1, revision: revision);

  Future<Result<void, SyncFailure>> begin({
    String operation = 'reserve-account',
    String? requestContext,
  }) => store.beginExitReserveRequest(
    operationId: operation,
    accountIdentity: 'account',
    sourceParent: parent,
    key: key,
    generation: 1,
    context: requestContext ?? context,
  );

  setUp(() {
    directory = Directory.systemTemp.createTempSync('exit-reserve-');
    store = ok(
      SqliteArkFundingReservations.open(
        '${directory.path}/journal',
        foreground: true,
        initializeNew: true,
      ),
    );
  });
  tearDown(() {
    store.close();
    directory.deleteSync(recursive: true);
  });

  test(
    'one account intent persists and retries cannot create a new one',
    () async {
      expect(await store.readExitReserveRequest('reserve-account'), isA<Ok>());
      expect(ok(await store.readExitReserveRequest('reserve-account')), isNull);
      expect(await begin(), isA<Ok>());
      expect(await begin(), isA<Err>());
      expect(await begin(operation: 'another'), isA<Err>());
      store.close();
      store = ok(
        SqliteArkFundingReservations.open(
          '${directory.path}/journal',
          foreground: true,
        ),
      );
      final saved = ok(await store.readExitReserveRequest('reserve-account'));
      expect(saved?.state, 'requested');
      expect(saved?.context, context);
      expect(saved?.confirmed, false);
      expect(await begin(), isA<Err>());
      final request = ok(await store.readUnpreparedRequest('reserve-account'));
      expect(request, isNotNull);
      if (request == null) return;
      expect(
        await store.closeNeverPrepared(
          expected: request,
          admittedRevision: stamp(2),
        ),
        isA<Err>(),
      );
    },
  );

  test(
    'two connections cannot claim distinct intents for one account',
    () async {
      final other = ok(
        SqliteArkFundingReservations.open(
          '${directory.path}/journal',
          foreground: true,
        ),
      );
      try {
        final results = await Future.wait([
          begin(),
          other.beginExitReserveRequest(
            operationId: 'different',
            accountIdentity: 'account',
            sourceParent: parent,
            key: key,
            generation: 1,
            context: context,
          ),
        ]);
        expect(results.whereType<Ok<void, SyncFailure>>(), hasLength(1));
        expect(results.whereType<Err<void, SyncFailure>>(), hasLength(1));
      } finally {
        other.close();
      }
    },
  );

  test(
    'reservation signing and confirmed evidence survive reopening',
    () async {
      ok(await begin());
      final spend = UnsignedSpend(
        revision: stamp(2),
        encoded: psbt,
        inputs: decodeBitcoinPsbt(psbt).inputs,
        owner: SpendOwner(protocol: 'ark', session: 'reserve-account'),
      );
      ok(await store.reserve(key: key, spend: spend, context: context));
      expect(
        ok(await store.unregisteredNeverSignedBoard('reserve-account')),
        isFalse,
      );
      final binding = ok(await store.readBinding('reserve-account'));
      expect(
        await store.tombstoneNeverSigned(
          expected: binding,
          admittedRevision: stamp(2),
        ),
        isA<Err>(),
      );
      expect(
        await store.beginSigning(expected: binding, admittedRevision: stamp(2)),
        isA<Err>(),
      );
      ok(
        await store.admitExitReserveSigning(
          expected: binding,
          admittedRevision: stamp(2),
        ),
      );
      expect(
        await store.admitExitReserveSigning(
          expected: binding,
          admittedRevision: stamp(2),
        ),
        isA<Err>(),
      );
      final bytes = base64Decode(psbt);
      final signed = base64Encode([
        ...bytes.take(bytes.length - 2),
        1,
        8,
        3,
        1,
        1,
        0x42,
        0,
        0,
      ]);
      ok(await store.recordSigned('reserve-account', signed));
      store.close();
      store = ok(
        SqliteArkFundingReservations.open(
          '${directory.path}/journal',
          foreground: true,
        ),
      );
      final before = ok(await store.readExitReserveRequest('reserve-account'));
      expect(before?.signedPsbt, signed);
      expect(before?.txid, decodeBitcoinPsbt(psbt).txid);
      expect(before?.confirmed, false);
      final tx = BitcoinTransaction(
        txid: decodeBitcoinPsbt(psbt).txid,
        feeSat: 200,
        vsize: decodeBitcoinPsbt(psbt).vsize,
        confirmationTime: 1700000000,
        inputs: [],
        outputs: [],
        sentSat: 100200,
        receivedSat: 0,
        isExplicitlyRbf: false,
      );
      ok(
        await store.observe(
          key,
          WalletTransactions.ready(ChainTransactionList([tx]), stamp(3)),
          admittedRevision: stamp(3),
        ),
      );
      final after = ok(await store.readExitReserveRequest('reserve-account'));
      expect(after?.state, 'confirmed');
      expect(after?.confirmed, true);
      expect(after?.txid, tx.txid);
      expect(after?.signedPsbt, signed);
      expect(await begin(operation: 'another'), isA<Err>());
    },
  );
}
