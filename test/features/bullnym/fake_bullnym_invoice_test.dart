import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/support/fake_bullnym_client.dart';

BullnymAuthSigner _signer(String npubHex) =>
    BullnymAuthSigner(npubHex: npubHex, signHashHex: (_) => 'sig');

BullnymCreateInvoiceFields _lnLiquid() => const BullnymCreateInvoiceFields(
  amountSat: 25000,
  acceptBtc: false,
  acceptLn: true,
  acceptLiquid: true,
  liquidAddress: 'lq1qtest',
  liquidBlindingKeyHex: 'ab12cd',
  expiresAtUnix: 1710086400,
);

void main() {
  late FakeBullnymClient client;
  final alice = _signer('a' * 64);
  final bob = _signer('b' * 64);

  setUp(() => client = FakeBullnymClient());

  test('create → list → status → cancel round-trip (unlinked)', () async {
    final created = await client.createInvoice(signer: alice, fields: _lnLiquid());
    expect(created.shareUrl, contains('/invoice/'));

    final list = await client.listInvoices(signer: alice, page: 1, pageSize: 100);
    expect(list.invoices.single.id, created.invoiceId);
    expect(list.invoices.single.nymOwner, isNull);

    final status = await client.getInvoiceStatus(invoiceId: created.invoiceId);
    expect(status.status, 'unpaid');

    final cancelled = await client.cancelInvoice(
      signer: alice,
      invoiceId: created.invoiceId,
    );
    expect(cancelled.status, 'cancelled');

    // Cancel is benign on an already-terminal invoice.
    final again = await client.cancelInvoice(
      signer: alice,
      invoiceId: created.invoiceId,
    );
    expect(again.status, 'cancelled');
  });

  test('the invoice store is independent of a bob-owned invoice', () async {
    await client.createInvoice(signer: alice, fields: _lnLiquid());
    final bobList = await client.listInvoices(signer: bob, page: 1, pageSize: 100);
    expect(bobList.invoices, isEmpty);
  });

  test('cancel of a non-owner id surfaces InvoiceNotFound', () async {
    final created = await client.createInvoice(signer: alice, fields: _lnLiquid());
    expect(
      () => client.cancelInvoice(signer: bob, invoiceId: created.invoiceId),
      throwsA(isA<BullnymException>().having((e) => e.code, 'code', 'InvoiceNotFound')),
    );
  });

  test('create enforces at-least-one-rail and rail↔address coherence', () async {
    expect(
      () => client.createInvoice(
        signer: alice,
        fields: const BullnymCreateInvoiceFields(
          amountSat: 1,
          acceptBtc: false,
          acceptLn: false,
          acceptLiquid: false,
          expiresAtUnix: 1710086400,
        ),
      ),
      throwsA(isA<BullnymException>().having((e) => e.code, 'code', 'InvalidAmount')),
    );
    expect(
      () => client.createInvoice(
        signer: alice,
        fields: const BullnymCreateInvoiceFields(
          amountSat: 1,
          acceptBtc: true,
          acceptLn: false,
          acceptLiquid: false,
          expiresAtUnix: 1710086400,
        ),
      ),
      throwsA(isA<BullnymException>().having((e) => e.code, 'code', 'InvalidAmount')),
    );
  });

  test('reusedLiquidAddressOnce fires once then clears', () async {
    client.invoiceMode = FakeInvoiceMode.reusedLiquidAddressOnce;
    expect(
      () => client.createInvoice(signer: alice, fields: _lnLiquid()),
      throwsA(
        isA<BullnymException>().having((e) => e.code, 'code', 'LiquidAddressAlreadyUsed'),
      ),
    );
    // The mode cleared itself; the retry succeeds.
    final retry = await client.createInvoice(signer: alice, fields: _lnLiquid());
    expect(retry.invoiceId, isNotEmpty);
  });

  test('featureDisabled makes signed create fail closed (404-class)', () async {
    client.invoiceMode = FakeInvoiceMode.featureDisabled;
    expect(
      () => client.createInvoice(signer: alice, fields: _lnLiquid()),
      throwsA(
        isA<BullnymException>().having(
          (e) => e.kind,
          'kind',
          BullnymErrorKind.unexpectedHttpStatus,
        ),
      ),
    );
  });

  test('list applies status filter and paging has_more', () async {
    for (var i = 0; i < 3; i++) {
      await client.createInvoice(signer: alice, fields: _lnLiquid());
    }
    final firstPage = await client.listInvoices(signer: alice, page: 1, pageSize: 2);
    expect(firstPage.invoices.length, 2);
    expect(firstPage.hasMore, isTrue);
    final unpaid = await client.listInvoices(
      signer: alice,
      page: 1,
      pageSize: 100,
      status: 'paid',
    );
    expect(unpaid.invoices, isEmpty);
  });
}
