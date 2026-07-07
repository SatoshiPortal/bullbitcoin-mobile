import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/fake_bullnym_client.dart';
import 'support/fake_nostr_relay.dart';
import 'support/get_paid_fixtures.dart';
import 'support/test_locator_overrides.dart';
import 'support/wipe_app_state.dart';

// SPEC-INV-01 — the fake-backed Invoices lifecycle round-trip.
//
// AUTHORED-BUT-CI-ONLY (flagged deviation, same rationale as SPEC-PP-01 /
// SPEC-POS-01): excluded from the aggregated L1 suite (tool/gen_all_test.dart
// skip set) because the live app-startup timers/blocs make an app-process run
// non-deterministic. The deterministic gates for this feature are the L0
// usecase/cubit suites; this file is retained for a dedicated CI job.

Future<void> main({bool isInitialized = false}) async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  Future<void> bootstrap(FakeBullnymClient bullnym) async {
    final relay = FakeNostrRelay();
    await wipeAppState(locator);
    await overrideBoundariesForTest(locator, relay: relay, bullnym: bullnym);
    // Default wallets only: invoices own no reserved wallet and need no nym.
    await locator<CreateDefaultWalletsUsecase>().execute(
      mnemonicWords: getPaidFixtureMnemonicWords,
    );
  }

  CreateInvoiceCommand liquidInvoice() => CreateInvoiceCommand(
        amountSat: 25000,
        acceptBtc: false,
        acceptLn: true,
        acceptLiquid: true,
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
        publicDescription: 'Coffee',
      );

  test('create (unlinked, default-wallet address + blinding key) -> list -> '
      'status -> cancel', () async {
    final bullnym = FakeBullnymClient();
    await bootstrap(bullnym);

    final created = await locator<InvoicesFacade>().create(liquidInvoice());
    // Unlinked v1: the public render is /invoice/:id.
    expect(created.shareUrl.value, contains('/invoice/'));

    // Payout discipline: the signed create carried an EMPTY nym slot and a
    // fresh Liquid address WITH its per-address blinding key (from the default
    // wallet, never a reserved descriptor).
    final call = bullnym.createInvoiceCalls.single;
    expect(call.nym, isNull);
    expect(call.fields.liquidAddress, isNotEmpty);
    expect(call.fields.liquidBlindingKeyHex, isNotEmpty);
    expect(call.fields.bitcoinAddress, anyOf(isNull, isEmpty));

    // The list shows it and the status polls unpaid.
    final listed = await locator<InvoicesFacade>().list(
      const ListInvoicesCommand(),
    );
    expect(listed.invoices.map((i) => i.id.value), contains(created.invoiceId.value));

    final status = await locator<InvoicesFacade>().status(created.invoiceId);
    expect(status.status, InvoiceStatus.unpaid);

    // Cancel (unpaid) settles to cancelled.
    final cancelled = await locator<InvoicesFacade>().cancel(
      CancelInvoiceCommand(invoiceId: created.invoiceId),
    );
    expect(cancelled.finalStatus, InvoiceStatus.cancelled);
    final after = await locator<InvoicesFacade>().status(created.invoiceId);
    expect(after.status, InvoiceStatus.cancelled);
  });

  test('reused Liquid address: the single regenerate-and-retry succeeds',
      () async {
    final bullnym = FakeBullnymClient()
      ..invoiceMode = FakeInvoiceMode.reusedLiquidAddressOnce;
    await bootstrap(bullnym);

    final created = await locator<InvoicesFacade>().create(liquidInvoice());
    expect(created.shareUrl.value, contains('/invoice/'));
    // Two create attempts were signed (the reuse, then the retry).
    expect(bullnym.createInvoiceCalls, hasLength(2));
    // The retry supplied a DIFFERENT fresh Liquid address.
    expect(
      bullnym.createInvoiceCalls[0].fields.liquidAddress,
      isNot(bullnym.createInvoiceCalls[1].fields.liquidAddress),
    );
  });

  test('feature-disabled server: create FAILS CLOSED, never a silent success',
      () async {
    final bullnym = FakeBullnymClient()
      ..invoiceMode = FakeInvoiceMode.featureDisabled;
    await bootstrap(bullnym);

    await expectLater(
      locator<InvoicesFacade>().create(liquidInvoice()),
      throwsA(isA<InvoicesException>()),
    );
  });
}
