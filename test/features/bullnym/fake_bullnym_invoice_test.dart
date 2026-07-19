import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/support/fake_bullnym_client.dart';

BullnymAuthSigner _signer(String npubHex) =>
    BullnymAuthSigner(npubHex: npubHex, signHashHex: (_) => 'sig');

BullnymCreateInvoiceFields _lnLiquid([int sequence = 1]) =>
    BullnymCreateInvoiceFields(
      amountSat: 25000,
      clientRequestId:
          '00000000-0000-4000-8000-${sequence.toString().padLeft(12, '0')}',
      presentationEnvelope: 'A' * 5500,
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
    final created = await client.createInvoice(
      signer: alice,
      fields: _lnLiquid(),
    );
    expect(created.invoiceUrl, contains('/invoice/'));

    final list = await client.listInvoices(
      signer: alice,
      page: 1,
      pageSize: 100,
    );
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
    final bobList = await client.listInvoices(
      signer: bob,
      page: 1,
      pageSize: 100,
    );
    expect(bobList.invoices, isEmpty);
  });

  test('cancel of a non-owner id surfaces InvoiceNotFound', () async {
    final created = await client.createInvoice(
      signer: alice,
      fields: _lnLiquid(),
    );
    expect(
      () => client.cancelInvoice(signer: bob, invoiceId: created.invoiceId),
      throwsA(
        isA<BullnymException>().having(
          (e) => e.code,
          'code',
          'InvoiceNotFound',
        ),
      ),
    );
  });

  test(
    'create enforces at-least-one-rail and rail↔address coherence',
    () async {
      expect(
        () => client.createInvoice(
          signer: alice,
          fields: BullnymCreateInvoiceFields(
            amountSat: 1,
            clientRequestId: '00000000-0000-4000-8000-000000000001',
            presentationEnvelope: 'A' * 5500,
            acceptBtc: false,
            acceptLn: false,
            acceptLiquid: false,
            expiresAtUnix: 1710086400,
          ),
        ),
        throwsA(
          isA<BullnymException>().having(
            (e) => e.code,
            'code',
            'InvalidAmount',
          ),
        ),
      );
      expect(
        () => client.createInvoice(
          signer: alice,
          fields: BullnymCreateInvoiceFields(
            amountSat: 1,
            clientRequestId: '00000000-0000-4000-8000-000000000001',
            presentationEnvelope: 'A' * 5500,
            acceptBtc: true,
            acceptLn: false,
            acceptLiquid: false,
            expiresAtUnix: 1710086400,
          ),
        ),
        throwsA(
          isA<BullnymException>().having(
            (e) => e.code,
            'code',
            'InvalidAmount',
          ),
        ),
      );
    },
  );

  test('reusedLiquidAddressOnce fires once then clears', () async {
    client.invoiceMode = FakeInvoiceMode.reusedLiquidAddressOnce;
    expect(
      () => client.createInvoice(signer: alice, fields: _lnLiquid()),
      throwsA(
        isA<BullnymException>().having(
          (e) => e.code,
          'code',
          'LiquidAddressAlreadyUsed',
        ),
      ),
    );
    // The mode cleared itself; the retry succeeds.
    final retry = await client.createInvoice(
      signer: alice,
      fields: _lnLiquid(),
    );
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
      await client.createInvoice(signer: alice, fields: _lnLiquid(i + 1));
    }
    final firstPage = await client.listInvoices(
      signer: alice,
      page: 1,
      pageSize: 2,
    );
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

  test('same request id is idempotent and changed payload conflicts', () async {
    final first = await client.createInvoice(
      signer: alice,
      fields: _lnLiquid(),
    );
    final retry = await client.createInvoice(
      signer: alice,
      fields: _lnLiquid(),
    );
    expect(retry.invoiceId, first.invoiceId);

    final changed = _lnLiquid();
    expect(
      () => client.createInvoice(
        signer: alice,
        fields: BullnymCreateInvoiceFields(
          amountSat: 25001,
          clientRequestId: changed.clientRequestId,
          presentationEnvelope: changed.presentationEnvelope,
          acceptBtc: changed.acceptBtc,
          acceptLn: changed.acceptLn,
          acceptLiquid: changed.acceptLiquid,
          liquidAddress: changed.liquidAddress,
          liquidBlindingKeyHex: changed.liquidBlindingKeyHex,
          expiresAtUnix: changed.expiresAtUnix,
        ),
      ),
      throwsA(
        isA<BullnymException>().having(
          (error) => error.code,
          'code',
          'InvoiceCreateConflict',
        ),
      ),
    );
  });
}
