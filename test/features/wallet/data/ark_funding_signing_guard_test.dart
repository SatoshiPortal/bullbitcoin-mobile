import 'package:ark/funding.dart';
import 'package:ark/ark.dart' show ArkWalletFailure;

import 'dart:async';
import 'dart:isolate';

import 'package:bull_ark/ark_wallet_setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sync/sync.dart';

import 'ark_funding_test_fixture.dart';

Future<Result<void, ArkWalletFailure>> _admit(
  ArkFundingSigningGuard guard,
  WalletKey key, {
  String unsignedPsbt = publicFundingPsbt,
}) => guard.admit(
  walletId: key.id,
  network: key.network,
  unsignedPsbt: unsignedPsbt,
);

// Separate isolate/SQLite connections start together; no signer or wallet opens.
Future<void> raceOrdinaryReservation((String, bool, SendPort) args) async {
  final (path, ordinary, parent) = args;
  final control = ReceivePort();
  SqliteArkFundingReservations? connection;
  parent.send(['control', control.sendPort]);
  try {
    final opened = sourceOk(
      SqliteArkFundingReservations.open(path, foreground: false),
    );
    connection = opened;
    parent.send(['ready']);
    if (await control.first != 'go') return;
    final result = ordinary
        ? await opened.admitOrdinarySigning(
            key: fundingKey,
            unsignedPsbt: publicFundingPsbt,
          )
        : await opened.reserve(
            key: fundingKey,
            spend: UnsignedSpend(
              revision: fundingStamp,
              encoded: publicFundingPsbt,
              inputs: decodeBitcoinPsbt(publicFundingPsbt).inputs,
              owner: SpendOwner(protocol: 'ark', session: 'racing'),
            ),
            context: 'public-context',
          );
    parent.send(['done', result is Ok]);
  } on Exception catch (error) {
    parent.send(['failed', error.runtimeType.toString()]);
  } finally {
    connection?.close();
    control.close();
  }
}

void main() {
  late FundingFixture fixture;
  setUp(() => fixture = FundingFixture());
  tearDown(() => fixture.close());

  for (final network in BitcoinNetwork.values) {
    test(
      'unavailable authority admits only explicit non-Ark Bitcoin $network',
      () async {
        const guard = ArkFundingSigningGuard(authority: null);
        final result = await _admit(
          guard,
          WalletKey(id: 'ordinary', network: network),
        );
        switch (network) {
          case BitcoinNetwork.mainnet:
          case BitcoinNetwork.testnet:
          case BitcoinNetwork.signet:
            expect(
              NetworkCapabilities.supports(network, NetworkCapability.ark),
              isFalse,
            );
            expect(result, isA<Ok<void, ArkWalletFailure>>());
          case BitcoinNetwork.regtest:
            expect(
              NetworkCapabilities.supports(network, NetworkCapability.ark),
              isTrue,
            );
            expect(result, isA<Err<void, ArkWalletFailure>>());
        }
      },
    );
  }
  for (final network in LiquidNetwork.values) {
    test(
      'non-Bitcoin $network does not gain the ordinary Bitcoin exception',
      () async {
        const guard = ArkFundingSigningGuard(authority: null);
        expect(
          await _admit(guard, WalletKey(id: 'not-bitcoin', network: network)),
          isA<Err<void, ArkWalletFailure>>(),
        );
      },
    );
  }
  test(
    'unavailable configured inventory refuses instead of an empty lookup',
    () async {
      const guard = ArkFundingSigningGuard(authority: null);
      expect(
        await _admit(guard, fundingKey),
        isA<Err<void, ArkWalletFailure>>(),
      );
    },
  );
  test(
    'ordinary handoff races future reservation in the same durable authority',
    () async {
      sourceOk(
        await fixture.store.begin(
          operationId: 'racing',
          accountIdentity: 'account',
          sourceParent: Fingerprint('00112233'),
          key: fundingKey,
          generation: 1,
          context: 'public-context',
        ),
      );
      final messages = ReceivePort();
      final stream = StreamIterator<dynamic>(messages);
      final exits = [ReceivePort(), ReceivePort()];
      final controls = <SendPort>[];
      final outcomes = <bool>[];
      for (var i = 0; i < 2; i++) {
        await Isolate.spawn(
          raceOrdinaryReservation,
          (fixture.path, i == 0, messages.sendPort),
          onExit: exits[i].sendPort,
          onError: messages.sendPort,
        );
      }
      try {
        var ready = 0;
        while (controls.length < 2 || ready < 2) {
          expect(await stream.moveNext(), isTrue);
          final event = stream.current;
          if (event case ['control', final SendPort port]) {
            controls.add(port);
          } else if (event case ['ready']) {
            ready++;
          } else {
            fail('Race worker prerequisite failed');
          }
        }
        for (final control in controls) {
          control.send('go');
        }
        while (outcomes.length < 2) {
          expect(await stream.moveNext(), isTrue);
          if (stream.current case ['done', final bool success]) {
            outcomes.add(success);
          } else {
            fail('Race worker operation failed before its result');
          }
        }
        expect(outcomes.where((success) => success), hasLength(1));
        final db = sqlite3.open(fixture.path);
        try {
          final markers = db
              .select('SELECT txid FROM ark_ordinary_signing')
              .length;
          final reservations = sourceOk(await fixture.store.reservations())
              .length;
          expect(markers + reservations, 1);
        } finally {
          db.close();
        }
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
    },
  );
  test(
    'ordinary handoff is durable and prevents later exact funding reservation',
    () async {
      final guard = ArkFundingSigningGuard(authority: fixture.store);
      expect(await _admit(guard, fundingKey), isA<Ok>());
      final reopened = sourceOk(
        SqliteArkFundingReservations.open(fixture.path, foreground: false),
      );
      try {
        sourceOk(
          await reopened.begin(
            operationId: 'late',
            accountIdentity: 'public-account',
            sourceParent: Fingerprint('00112233'),
            key: fundingKey,
            generation: 1,
            context: 'public-context',
          ),
        );
        expect(
          await reopened.reserve(
            key: fundingKey,
            spend: UnsignedSpend(
              revision: fundingStamp,
              encoded: publicFundingPsbt,
              inputs: decodeBitcoinPsbt(publicFundingPsbt).inputs,
              owner: SpendOwner(protocol: 'ark', session: 'late'),
            ),
            context: 'public-context',
          ),
          isA<Err>(),
        );
        switch (await reopened.getCustodyFingerprints()) {
          case Ok(:final value):
            expect(value, contains(Fingerprint('00112233')));
          case Err():
            fail('custody inventory failed');
        }
      } finally {
        reopened.close();
      }
    },
  );
  test('Ark wins first: exact transaction and wallet alias refuse ordinary handoff', () async {
    await fixture.reserve('ark-first');
    final guard = ArkFundingSigningGuard(authority: fixture.store);
    for (final key in [
      fundingKey,
      WalletKey(id: 'alias', network: BitcoinNetwork.regtest),
    ]) {
      expect(await _admit(guard, key), isA<Err>());
    }
    final db = sqlite3.open(fixture.path);
    try {
      expect(db.select('SELECT * FROM ark_ordinary_signing'), isEmpty);
    } finally {
      db.close();
    }
  });
  test('ordinary marker is exact txid, not a global input blacklist', () async {
    final other = otherUnsignedTransaction();
    sourceOk(inspectBitcoinPsbt(other));
    expect(
      decodeBitcoinPsbt(other).txid,
      isNot(decodeBitcoinPsbt(publicFundingPsbt).txid),
    );
    expect(
      decodeBitcoinPsbt(other).inputs,
      decodeBitcoinPsbt(publicFundingPsbt).inputs,
    );
    expect(
      await _admit(
        ArkFundingSigningGuard(authority: fixture.store),
        fundingKey,
      ),
      isA<Ok>(),
    );
    await fixture.reserve('different-exact-transaction', psbt: other);
    expect(sourceOk(await fixture.store.reservations()), hasLength(1));
  });
  test(
    'active input overlap and corrupt unrelated inventory refuse admission',
    () async {
      await fixture.reserve('active');
      final guard = ArkFundingSigningGuard(authority: fixture.store);
      expect(
        await _admit(
          guard,
          fundingKey,
          unsignedPsbt: otherUnsignedTransaction(),
        ),
        isA<Err>(),
      );
      final db = sqlite3.open(fixture.path);
      try {
        db.execute("UPDATE ark_funding_operations SET state='invalid'");
      } finally {
        db.close();
      }
      expect(await _admit(guard, fundingKey), isA<Err>());
    },
  );
  test(
    'ordinary marker retries are idempotent while scopes remain network-wide',
    () async {
      final guard = ArkFundingSigningGuard(authority: fixture.store);
      expect(await _admit(guard, fundingKey), isA<Ok>());
      expect(
        await _admit(
          guard,
          WalletKey(id: 'alias', network: BitcoinNetwork.regtest),
        ),
        isA<Ok>(),
      );
      final db = sqlite3.open(fixture.path);
      try {
        expect(db.select('SELECT * FROM ark_ordinary_signing'), hasLength(1));
      } finally {
        db.close();
      }
    },
  );
  test(
    'locked write cannot admit a signer before durable marker commit',
    () async {
      final other = sqlite3.open(fixture.path);
      try {
        other.execute('BEGIN IMMEDIATE');
        expect(
          await _admit(
            ArkFundingSigningGuard(authority: fixture.store),
            fundingKey,
          ),
          isA<Err>(),
        );
        other.execute('ROLLBACK');
        expect(other.select('SELECT * FROM ark_ordinary_signing'), isEmpty);
      } finally {
        other.close();
      }
    },
  );
  for (final foreground in [false, true]) {
    for (final initializeNew in [false, true]) {
      test(
        'lost ordinary handoff table refuses foreground=$foreground initializeNew=$initializeNew',
        () async {
          sourceOk(
            await fixture.store.admitOrdinarySigning(
              key: fundingKey,
              unsignedPsbt: publicFundingPsbt,
            ),
          );
          final db = sqlite3.open(fixture.path);
          try {
            expect(
              db.select('SELECT * FROM ark_ordinary_signing'),
              hasLength(1),
            );
            db.execute('DROP TABLE ark_ordinary_signing');
          } finally {
            db.close();
          }
          final reopened = SqliteArkFundingReservations.open(
            fixture.path,
            foreground: foreground,
            initializeNew: initializeNew,
          );
          if (reopened case Ok(:final value)) value.close();
          expect(reopened, isA<Err>());
          final check = sqlite3.open(fixture.path);
          try {
            expect(
              check.select(
                "SELECT name FROM sqlite_master WHERE name='ark_ordinary_signing'",
              ),
              isEmpty,
            );
          } finally {
            check.close();
          }
        },
      );
    }
  }
}
