import 'package:bb_mobile/core/utils/result.dart';
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
    final created = _unwrap(
      await client.createInvoice(signer: alice, fields: _lnLiquid()),
    );
    expect(created.invoiceUrl, contains('/invoice/'));

    final list = _unwrap(
      await client.listInvoices(signer: alice, page: 1, pageSize: 100),
    );
    expect(list.invoices.single.id, created.invoiceId);
    expect(list.invoices.single.nymOwner, isNull);

    final status = _unwrap(
      await client.getInvoiceStatus(invoiceId: created.invoiceId),
    );
    expect(status.status, 'unpaid');

    final cancelled = _unwrap(
      await client.cancelInvoice(signer: alice, invoiceId: created.invoiceId),
    );
    expect(cancelled.status, 'cancelled');

    // Cancel is benign on an already-terminal invoice.
    final again = _unwrap(
      await client.cancelInvoice(signer: alice, invoiceId: created.invoiceId),
    );
    expect(again.status, 'cancelled');
  });

  test('the invoice store is independent of a bob-owned invoice', () async {
    _unwrap(await client.createInvoice(signer: alice, fields: _lnLiquid()));
    final bobList = _unwrap(
      await client.listInvoices(signer: bob, page: 1, pageSize: 100),
    );
    expect(bobList.invoices, isEmpty);
  });

  test('cancel of a non-owner id surfaces InvoiceNotFound', () async {
    final created = _unwrap(
      await client.createInvoice(signer: alice, fields: _lnLiquid()),
    );
    final failure = _unwrapFailure(
      await client.cancelInvoice(signer: bob, invoiceId: created.invoiceId),
    );
    expect(failure.code, 'InvoiceNotFound');
  });

  test(
    'create enforces at-least-one-rail and rail↔address coherence',
    () async {
      final noRailFailure = _unwrapFailure(
        await client.createInvoice(
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
      );
      expect(noRailFailure.code, 'InvalidAmount');
      final noAddressFailure = _unwrapFailure(
        await client.createInvoice(
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
      );
      expect(noAddressFailure.code, 'InvalidAmount');
    },
  );

  test('reusedLiquidAddressOnce fires once then clears', () async {
    client.invoiceMode = FakeInvoiceMode.reusedLiquidAddressOnce;
    final failure = _unwrapFailure(
      await client.createInvoice(signer: alice, fields: _lnLiquid()),
    );
    expect(failure.code, 'LiquidAddressAlreadyUsed');
    // The mode cleared itself; the retry succeeds.
    final retry = _unwrap(
      await client.createInvoice(signer: alice, fields: _lnLiquid()),
    );
    expect(retry.invoiceId, isNotEmpty);
  });

  test('featureDisabled makes signed create fail closed (404-class)', () async {
    client.invoiceMode = FakeInvoiceMode.featureDisabled;
    final failure = _unwrapFailure(
      await client.createInvoice(signer: alice, fields: _lnLiquid()),
    );
    expect(failure.kind, BullnymFailureKind.unexpectedHttpStatus);
  });

  test('list applies status filter and paging has_more', () async {
    for (var i = 0; i < 3; i++) {
      _unwrap(
        await client.createInvoice(signer: alice, fields: _lnLiquid(i + 1)),
      );
    }
    final firstPage = _unwrap(
      await client.listInvoices(signer: alice, page: 1, pageSize: 2),
    );
    expect(firstPage.invoices.length, 2);
    expect(firstPage.hasMore, isTrue);
    final unpaid = _unwrap(
      await client.listInvoices(
        signer: alice,
        page: 1,
        pageSize: 100,
        status: 'paid',
      ),
    );
    expect(unpaid.invoices, isEmpty);
  });

  test('same request id is idempotent and changed payload conflicts', () async {
    final first = _unwrap(
      await client.createInvoice(signer: alice, fields: _lnLiquid()),
    );
    final retry = _unwrap(
      await client.createInvoice(signer: alice, fields: _lnLiquid()),
    );
    expect(retry.invoiceId, first.invoiceId);

    final changed = _lnLiquid();
    final failure = _unwrapFailure(
      await client.createInvoice(
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
    );
    expect(failure.code, 'InvoiceCreateConflict');
  });
}

T _unwrap<T>(Result<T, BullnymFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError('Expected Ok, got $failure'),
};

BullnymFailure _unwrapFailure<T>(Result<T, BullnymFailure> result) =>
    switch (result) {
      Ok() => throw StateError('Expected Err, got Ok'),
      Err(:final failure) => failure,
    };
