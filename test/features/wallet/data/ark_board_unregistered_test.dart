import 'dart:convert';

import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'ark_funding_test_fixture.dart';

/// A Board that stopped after reserving its coin but before Ark registered it
/// has no review, and signing needs one, so its coin must not stay held.
void main() {
  late FundingFixture fixture;
  setUp(() => fixture = FundingFixture());
  tearDown(() => fixture.close());

  void sql(void Function(Database) action) {
    final db = sqlite3.open(fixture.path);
    try {
      action(db);
    } finally {
      db.close();
    }
  }

  test('a reservation Ark never registered gives its coin back', () async {
    final binding = await fixture.reserve('op');
    expect(sourceOk(await fixture.store.reservations()), hasLength(1));
    expect(
      sourceOk(await fixture.store.unregisteredNeverSignedBoard('op')),
      isTrue,
    );
    sourceOk(
      await fixture.store.tombstoneNeverSigned(
        expected: binding,
        admittedRevision: fundingStamp,
      ),
    );
    expect(sourceOk(await fixture.store.reservations()), isEmpty);
    expect(
      sourceOk(await fixture.store.pendingForAccount('public-account')),
      isNull,
    );
    // Released for good: it can never be signed afterwards.
    expect(
      await fixture.store.admitBoardSigning(
        expected: binding,
        admittedRevision: fundingStamp,
      ),
      isA<Err>(),
    );
    expect(
      sourceOk(await fixture.store.unregisteredNeverSignedBoard('op')),
      isFalse,
    );
  });

  test(
    'a registered Board, with its review, is never released this way',
    () async {
      await fixture.reserve('op');
      sourceOk(
        await fixture.store.saveBoardReview(
          'op',
          jsonEncode({
            'request': 'public-context',
            'address': 'public-address',
            'keypairIndex': 1,
            'expiryHeight': 5000,
            'minerFee': 200,
          }),
        ),
      );
      expect(
        sourceOk(await fixture.store.unregisteredNeverSignedBoard('op')),
        isFalse,
      );
      expect(sourceOk(await fixture.store.reservations()), hasLength(1));
    },
  );

  for (final state in ['started', 'unknown', 'legacy']) {
    test('a $state signing record keeps its coin held', () async {
      final binding = await fixture.reserve('op');
      sql(
        (db) => state == 'legacy'
            ? db.execute('DELETE FROM ark_funding_authority')
            : db.execute('UPDATE ark_funding_authority SET signing=?', [state]),
      );
      expect(
        sourceOk(await fixture.store.unregisteredNeverSignedBoard('op')),
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
    });
  }
}
