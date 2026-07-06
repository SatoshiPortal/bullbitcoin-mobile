import 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_error.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/support/fake_bullnym_client.dart';

// T-POS-FAKE: the in-memory fake's POS behaviours. Kept at L0 because
// the fake is a pure Dart in-memory model with no binding dependency.
BullnymSaveDonationPageRequest _save({
  String nym = 'alice',
  required String kind,
  String ctDescriptor = 'ct(desc)',
  String header = 'My Till',
  String displayCurrency = 'CAD',
}) {
  return BullnymSaveDonationPageRequest(
    nym: nym,
    ctDescriptor: ctDescriptor,
    header: header,
    description: '',
    displayCurrency: displayCurrency,
    website: '',
    twitter: '',
    instagram: '',
    enabled: true,
    kind: kind,
    npubHex: 'npub',
    signatureHex: 'sig',
    timestamp: 1710000000,
  );
}

BullnymArchiveDonationPageRequest _archive({
  String nym = 'alice',
  required String kind,
}) {
  return BullnymArchiveDonationPageRequest(
    nym: nym,
    kind: kind,
    npubHex: 'npub',
    signatureHex: 'sig',
    timestamp: 1710000000,
  );
}

void main() {
  late FakeBullnymClient client;

  setUp(() => client = FakeBullnymClient());

  test('hard-rejects a descriptorless kind=pos save (KR-1 server backstop)', () {
    expect(
      () => client.saveDonationPage(_save(kind: 'pos', ctDescriptor: '')),
      throwsA(
        isA<BullnymException>().having(
          (e) => e.code,
          'code',
          'DonationPageInvalid',
        ),
      ),
    );
  });

  test('a kind=pos save persists a row and echoes the /pos public url', () async {
    final saved = await client.saveDonationPage(_save(kind: 'pos'));

    expect(saved.kind, 'pos');
    expect(saved.publicUrl, endsWith('/alice/pos'));

    final fetched = await client.getDonationPage(nym: 'alice', kind: 'pos');
    expect(fetched.header, 'My Till');
  });

  test('the (nym,pos) row is independent of the (nym,payment_page) row', () async {
    await client.saveDonationPage(_save(kind: 'payment_page', header: 'Page'));
    await client.saveDonationPage(_save(kind: 'pos', header: 'Till'));

    final page = await client.getDonationPage(
      nym: 'alice',
      kind: 'payment_page',
    );
    final pos = await client.getDonationPage(nym: 'alice', kind: 'pos');
    expect(page.header, 'Page');
    expect(pos.header, 'Till');

    // Archiving the POS leaves the page row live and untouched (coexistence).
    await client.archiveDonationPage(_archive(kind: 'pos'));
    final pageAfter = await client.getDonationPage(
      nym: 'alice',
      kind: 'payment_page',
    );
    expect(pageAfter.isArchived, isFalse);
  });

  test('posMode faults only affect kind=pos, never the page', () async {
    await client.saveDonationPage(_save(kind: 'payment_page', header: 'Page'));
    await client.saveDonationPage(_save(kind: 'pos', header: 'Till'));

    // missing: pos GET throws NotFound; the page GET still returns.
    client.posMode = FakePosMode.missing;
    expect(
      () => client.getDonationPage(nym: 'alice', kind: 'pos'),
      throwsA(
        isA<BullnymException>().having(
          (e) => e.code,
          'code',
          'DonationPageNotFound',
        ),
      ),
    );
    expect(
      (await client.getDonationPage(nym: 'alice', kind: 'payment_page')).header,
      'Page',
    );

    // archived: pos GET returns archived; the page GET stays live.
    client.posMode = FakePosMode.archived;
    expect(
      (await client.getDonationPage(nym: 'alice', kind: 'pos')).isArchived,
      isTrue,
    );
    expect(
      (await client.getDonationPage(nym: 'alice', kind: 'payment_page'))
          .isArchived,
      isFalse,
    );

    // saveAuthError: a kind=pos save fails closed with AuthError (pre-release).
    client.posMode = FakePosMode.saveAuthError;
    expect(
      () => client.saveDonationPage(_save(kind: 'pos')),
      throwsA(
        isA<BullnymException>().having((e) => e.code, 'code', 'AuthError'),
      ),
    );

    // serverUnreachable: pos calls throw retryable; the page GET is unaffected.
    client.posMode = FakePosMode.serverUnreachable;
    expect(
      () => client.getDonationPage(nym: 'alice', kind: 'pos'),
      throwsA(
        isA<BullnymException>().having((e) => e.retryable, 'retryable', true),
      ),
    );
    expect(
      (await client.getDonationPage(nym: 'alice', kind: 'payment_page')).header,
      'Page',
    );
  });
}
