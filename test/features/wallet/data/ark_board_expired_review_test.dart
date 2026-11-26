import 'package:ark/funding.dart';

import 'dart:convert';

import 'package:bull_ark/ark_wallet_setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sync/sync.dart';

import 'ark_funding_test_fixture.dart';

void main() {
  final now = DateTime.utc(2026, 11, 17, 12);
  late FundingFixture fixture;
  setUp(() => fixture = FundingFixture());
  tearDown(() => fixture.close());

  Future<ArkFundingBinding> prepared({bool expired = true}) async {
    final context = jsonEncode({
      'version': 1,
      'account': 'public-account',
      'validUntil':
          (expired
                  ? now.subtract(const Duration(minutes: 1))
                  : now.add(const Duration(minutes: 1)))
              .toIso8601String(),
    });
    final binding = await fixture.reserve('op', context: context);
    sourceOk(
      await fixture.store.saveBoardReview(
        'op',
        jsonEncode({
          'request': context,
          'address': 'public-address',
          'keypairIndex': 1,
          'expiryHeight': 5000,
          'minerFee': 200,
        }),
      ),
    );
    return binding;
  }

  void sql(void Function(Database) action) {
    final db = sqlite3.open(fixture.path);
    try {
      action(db);
    } finally {
      db.close();
    }
  }

  test('expired prepared never-started binding uses the existing durable tombstone', () async {
    final binding = await prepared();
    expect(
      sourceOk(await fixture.store.expiredUnsignedBoardReview('op', now)),
      isTrue,
    );
    sourceOk(
      await fixture.store.tombstoneNeverSigned(
        expected: binding,
        admittedRevision: fundingStamp,
      ),
    );
    expect(
      sourceOk(await fixture.store.pendingForAccount('public-account')),
      isNull,
    );
    expect(sourceOk(await fixture.store.reservations()), isEmpty);
    sql((db) {
      final row = db.select('SELECT * FROM ark_funding_operations').single;
      expect(row['state'], 'tombstoned');
      expect(row['psbt'], binding.unsignedPsbt);
      expect(row['txid'], binding.unsignedTxid);
      expect(row['context'], binding.context);
      expect(db.select('SELECT * FROM ark_board_reviews'), hasLength(1));
      final receipt = jsonDecode(
        db
                .select('SELECT settlement FROM ark_funding_authority')
                .single['settlement']
            as String,
      ) as Map<String, dynamic>;
      expect(receipt['version'], 1);
      expect(receipt['kind'], 'neverSigned');
      expect(receipt['closed'], isTrue);
    });
    final reopened = sourceOk(
      SqliteArkFundingReservations.open(fixture.path, foreground: false),
    );
    try {
      expect(sourceOk(await reopened.reservations()), isEmpty);
      expect(await reopened.readBoardReview('op'), isA<Err>());
      expect(
        await reopened.admitBoardSigning(
          expected: binding,
          admittedRevision: fundingStamp,
        ),
        isA<Err>(),
      );
      for (final key in [
        fundingKey,
        WalletKey(id: 'alias', network: BitcoinNetwork.regtest),
      ]) {
        expect(
          await ArkFundingSigningGuard(authority: reopened).admit(
            walletId: key.id,
            network: key.network,
            unsignedPsbt: binding.unsignedPsbt,
          ),
          isA<Err>(),
        );
      }
    } finally {
      reopened.close();
    }
  });

  test(
    'an unexpired review is not eligible and keeps its reservation',
    () async {
      await prepared(expired: false);
      expect(
        sourceOk(await fixture.store.expiredUnsignedBoardReview('op', now)),
        isFalse,
      );
      expect(sourceOk(await fixture.store.reservations()), hasLength(1));
    },
  );

  for (final state in ['started', 'signed', 'unknown', 'legacy']) {
    test('$state cannot become an expired unsigned release', () async {
      final binding = await prepared();
      switch (state) {
        case 'started':
        case 'signed':
          sourceOk(
            await fixture.store.admitBoardSigning(
              expected: binding,
              admittedRevision: fundingStamp,
            ),
          );
          if (state == 'signed') {
            final signed = structuralFinalWitness();
            expect(
              sourceOk(inspectBitcoinPsbt(signed)).finalTransaction,
              isNotNull,
            );
            sourceOk(await fixture.store.recordSigned('op', signed));
          }
        case 'unknown':
          sql(
            (db) => db.execute(
              "UPDATE ark_funding_authority SET signing='unknown'",
            ),
          );
        case 'legacy':
          sql((db) => db.execute('DELETE FROM ark_funding_authority'));
      }
      expect(
        sourceOk(await fixture.store.expiredUnsignedBoardReview('op', now)),
        isFalse,
      );
      expect(
        await fixture.store.tombstoneNeverSigned(
          expected: binding,
          admittedRevision: fundingStamp,
        ),
        isA<Err>(),
      );
      expect(sourceOk(await fixture.store.reservations()), hasLength(1));
      expect(
        sourceOk(await fixture.store.pendingForAccount('public-account')),
        'op',
      );
    });
  }

  test(
    'a signer starting after expiry qualification wins against release',
    () async {
      final binding = await prepared();
      expect(
        sourceOk(await fixture.store.expiredUnsignedBoardReview('op', now)),
        isTrue,
      );
      final other = sourceOk(
        SqliteArkFundingReservations.open(fixture.path, foreground: false),
      );
      try {
        sourceOk(
          await other.admitBoardSigning(
            expected: binding,
            admittedRevision: fundingStamp,
          ),
        );
        expect(
          await fixture.store.tombstoneNeverSigned(
            expected: binding,
            admittedRevision: fundingStamp,
          ),
          isA<Err>(),
        );
        expect(sourceOk(await fixture.store.reservations()), hasLength(1));
        expect(sourceOk(await other.readBoardReview('op')).signedPsbt, isNull);
      } finally {
        other.close();
      }
    },
  );

  for (final ambiguity in [
    'signed-original',
    'context-version',
    'review-context',
  ]) {
    test(
      '$ambiguity refuses expiry qualification instead of inferring no signature',
      () async {
        final binding = await prepared();
        sql((db) {
          switch (ambiguity) {
            case 'signed-original':
              final signed = structuralFinalWitness();
              final facts = sourceOk(inspectBitcoinPsbt(signed));
              expect(facts.unsignedTxid, binding.unsignedTxid);
              expect(facts.finalTransaction, isNotNull);
              db.execute('UPDATE ark_funding_operations SET psbt=?', [signed]);
            case 'context-version':
              final context =
                  jsonDecode(binding.context) as Map<String, dynamic>;
              context['version'] = 1.0;
              final encoded = jsonEncode(context);
              db.execute('UPDATE ark_funding_operations SET context=?', [
                encoded,
              ]);
              db.execute('UPDATE ark_board_reviews SET payload=?', [
                jsonEncode({'request': encoded}),
              ]);
            case 'review-context':
              db.execute('UPDATE ark_board_reviews SET payload=?', [
                '{"request":"different"}',
              ]);
          }
        });
        expect(
          await fixture.store.expiredUnsignedBoardReview('op', now),
          isA<Err>(),
        );
        sql(
          (db) => expect(
            db.select('SELECT * FROM ark_funding_inputs'),
            hasLength(1),
          ),
        );
      },
    );
  }
}
