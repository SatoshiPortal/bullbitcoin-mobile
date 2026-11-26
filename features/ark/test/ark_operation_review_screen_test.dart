import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/ark_repository_impl.dart';
import 'package:bull_ark/src/domain/ark_display_data_port.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/usecases/confirm_ark_operation_usecase.dart';
import 'package:bull_ark/src/domain/usecases/quote_ark_operation_usecase.dart';
import 'package:bull_ark/src/presentation/ark_operation_cubit.dart';
import 'package:bull_ark/src/ui/ark_amount.dart';
import 'package:bull_ark/src/ui/ark_operation_review_screen.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullDetailsTable,
        BullDetailsTableItem,
        BullTopBar,
        SingleChildScrollView,
        ValueKey,
        SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show KeyedSubtree, Offset, Size;
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app;
import 'ark_operations_test.dart' show account, Preferences;
import 'fake_ark_client.dart';

ArkQuote reviewed(ArkAccountId owner, {int amount = 1000}) => ArkQuote(
  id: 'same-quote-id',
  account: owner,
  generation: 2,
  chainSource: Uri.parse('http://localhost:3000'),
  configGeneration: 1,
  kind: ArkOperationKind.renewal,
  amount: Sats.fromInt(amount),
  fee: Sats.fromInt(100),
  net: Sats.fromInt(amount - 100),
  selectedIds: ['selected-vtxo'],
  destination: 'reviewed-destination',
  observedTip: 100,
  validUntil: DateTime.utc(2030),
);

class Client extends FakeArkClient {
  Completer<Result<ArkQuote, ArkWalletFailure>>? quoteReply;
  Completer<Result<ArkOperation, ArkWalletFailure>>? submitReply;
  Client() {
    quoted = const Err(ArkUnavailableFailure());
    submitted = const Err(ArkStorageFailure());
  }
  @override
  Future<Result<ArkQuote, ArkWalletFailure>> quote(
    ArkAccountId account,
    ArkQuoteRequest request,
  ) {
    final reply = quoteReply;
    if (reply == null) return super.quote(account, request);
    calls.add('quote');
    arguments.add((account, request));
    return reply.future;
  }

  @override
  Future<Result<ArkOperation, ArkWalletFailure>> submit(
    ArkAccountId account,
    ArkSubmission submission,
  ) {
    final reply = submitReply;
    if (reply == null) return super.submit(account, submission);
    calls.add('submit');
    arguments.add((account, submission));
    return reply.future;
  }
}

class Rig {
  final client = Client();
  late final ArkOperationCubit cubit;
  int ids = 0, reconciles = 0;
  Rig({ArkAccountId? owner, ArkQuoteRequest? request}) {
    final repository = ArkRepositoryImpl(client);
    cubit = ArkOperationCubit(
      QuoteArkOperationUsecase(repository, Preferences()),
      ConfirmArkOperationUsecase(repository, Preferences()),
      () => 'attempt-${++ids}',
      account: owner ?? account(),
      request: request ?? ArkQuoteRequest.renewal(ids: ['selected-vtxo']),
    );
    addTearDown(cubit.close);
  }
  ArkOperationReviewScreen get screen =>
      ArkOperationReviewScreen(cubit: cubit, onReconcile: () => reconciles++);
  Future<void> ready({int amount = 1000}) async {
    client.quoted = Ok(reviewed(cubit.account, amount: amount));
    await cubit.load();
  }
}

BullButton button(WidgetTester tester, String label) {
  final finder = find.widgetWithText(BullButton, label);
  expect(finder, findsOneWidget, reason: 'Expected explicit $label action');
  return tester.widget<BullButton>(finder);
}

Map<String, String?> details(WidgetTester tester) => {
  for (final table in tester.widgetList<BullDetailsTable>(
    find.byType(BullDetailsTable),
  ))
    for (final item in table.items.whereType<BullDetailsTableItem>())
      item.label: item.displayValue,
};

// Drain asynchronous Cubit delivery before rendering its scheduled frame.
Future<void> pumpState(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

// Let a leaving screen show its snackbar after the frame.
Future<void> pumpLeave(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('payment review reads as the Send confirmation step', (
    tester,
  ) async {
    final r = Rig(
      request: ArkQuoteRequest.payment(
        destination: ArkPaymentDestination(
          kind: ArkDestinationKind.ark,
          value: 'reviewed-destination',
        ),
        amount: Sats.fromInt(1000),
      ),
    );
    final base = reviewed(r.cubit.account);
    r.client.quoted = Ok(
      ArkQuote(
        id: base.id,
        account: base.account,
        generation: base.generation,
        chainSource: base.chainSource,
        configGeneration: base.configGeneration,
        kind: ArkOperationKind.payment,
        amount: base.amount,
        fee: base.fee,
        net: base.net,
        selectedIds: base.selectedIds,
        destination: base.destination,
        observedTip: base.observedTip,
        validUntil: base.validUntil,
      ),
    );
    await r.cubit.load();
    await tester.pumpWidget(app(r.screen));
    await pumpState(tester);
    expect(tester.widget<BullTopBar>(find.byType(BullTopBar)).title, 'Send');
    expect(find.text('Confirm Send'), findsOneWidget);
    expect(details(tester), {
      'From': 'Ark',
      'To': 'reviewed-destination',
      'Amount': '900 sats',
      'Network fees': '100 sats',
      'Total': '1,000 sats',
    });
    expect(button(tester, 'Confirm').disabled, false);
    expect(r.client.calls, ['quote']);
  });
  testWidgets(
    'incomplete progression quote keeps defensive confirm without a net hero',
    (tester) async {
      final r = Rig(request: ArkQuoteRequest.exitProgress(feeRate: FeeRate(2)));
      // Deliberately mismatched fixture: request/quote facts must remain closed.
      r.cubit.emit(ArkOperationReview(reviewed(r.cubit.account)));
      await tester.pumpWidget(app(r.screen));
      await pumpState(tester);
      expect(button(tester, 'Confirm').disabled, true);
      expect(find.text('900 sats'), findsNothing);
      expect(find.byType(ArkFiatAmount), findsNothing);
      expect(details(tester)['Net amount (sats)'], '900');
      button(tester, 'Confirm').onPressed();
      await pumpState(tester);
      expect(r.client.calls, isEmpty);
      expect(r.ids, 0);
    },
  );

  testWidgets(
    'review keeps quote net, header and confirm footer at phone size',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final r = Rig();
      await r.ready();
      await tester.pumpWidget(app(r.screen));
      await pumpState(tester);
      expect(find.text('900 sats'), findsOneWidget);
      expect(details(tester)['Net amount (sats)'], '900');
      final footer = find.widgetWithText(BullButton, 'Confirm');
      final header = find.byType(BullTopBar);
      final headerY = tester.getTopLeft(header).dy;
      final footerY = tester.getTopLeft(footer).dy;
      expect(tester.getBottomRight(footer).dy, greaterThan(780));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(header).dy, headerY);
      expect(tester.getTopLeft(footer).dy, footerY);
      expect(r.client.calls, ['quote']);
      expect(r.ids, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fiat observation is matched to the reviewing account only', (
    tester,
  ) async {
    final r = Rig();
    await r.ready();
    final price = BitcoinPrice(
      currency: SupportedCurrency.cad,
      fiatAmount: 100000,
      fetchedAt: DateTime.utc(2026, 11, 17),
    );
    final owner = r.cubit.account;
    for (final matches in [true, false]) {
      await tester.pumpWidget(
        app(
          ArkOperationReviewScreen(
            cubit: r.cubit,
            onReconcile: () {},
            displayData: ArkDisplayData(
              account: matches
                  ? owner
                  : ArkAccountId(
                      parent: owner.parent,
                      network: owner.network,
                      serverIdentity: 'other',
                    ),
              walletId: 'source',
              available: Sats.fromInt(100000),
              price: price,
            ),
          ),
        ),
      );
      await pumpState(tester);
      final equivalent = tester.widget<ArkFiatAmount>(
        find.byType(ArkFiatAmount),
      );
      expect(equivalent.amount, Sats.fromInt(900));
      expect(equivalent.price, matches ? price : isNull);
      expect(r.client.calls, ['quote']);
    }
  });

  for (final (request, kind, label)
      in <(ArkQuoteRequest, ArkOperationKind, String)>[
        (
          ArkQuoteRequest.renewal(ids: ['selected-vtxo']),
          ArkOperationKind.renewal,
          'Renewal started',
        ),
        (
          ArkQuoteRequest.emergencyExit(
            ids: ['selected-vtxo'],
            destination: 'destination',
            feeRate: FeeRate(2),
            maxClaimFee: Sats.fromInt(1000),
          ),
          ArkOperationKind.emergencyExit,
          'Emergency exit started',
        ),
        (
          ArkQuoteRequest.payment(
            destination: ArkPaymentDestination(
              kind: ArkDestinationKind.ark,
              value: 'ark-destination',
            ),
            amount: Sats.fromInt(1000),
          ),
          ArkOperationKind.payment,
          'Payment sent',
        ),
      ]) {
    testWidgets(
      'native $kind submission leaves with its backend status and no success page',
      (tester) async {
        final r = Rig(request: request);
        var mounts = 0;
        for (final status in ArkOperationStatus.values) {
          // A fresh page per submission: each one leaves exactly once.
          await tester.pumpWidget(
            app(KeyedSubtree(key: ValueKey(status), child: r.screen)),
          );
          await pumpState(tester);
          mounts++;
          r.cubit.emit(
            ArkOperationSubmitted(
              ArkOperation(
                id: 'native-id',
                kind: kind,
                status: status,
                chainSource: Uri.parse('http://localhost:3000'),
                configGeneration: 1,
              ),
            ),
          );
          await pumpLeave(tester);
          expect(find.text(statusLabel(status).$1), findsOneWidget);
          expect(find.text(label), findsNothing);
          expect(r.reconciles, mounts);
          expect(find.widgetWithText(BullButton, 'Confirm'), findsNothing);
          expect(find.text('900 sats'), findsNothing);
          await tester.pump(const Duration(seconds: 4));
        }
        expect(r.client.calls, isEmpty);
        expect(r.ids, 0);
      },
    );
  }

  testWidgets('mount and replacement never quote an unstarted owner', (
    tester,
  ) async {
    final a = Rig();
    final b = Rig();
    await tester.pumpWidget(app(a.screen));
    await pumpState(tester);
    expect(a.client.calls, isEmpty);
    await tester.pumpWidget(app(b.screen));
    await pumpState(tester);
    expect(b.client.calls, isEmpty);
    expect(find.widgetWithText(BullButton, 'Review'), findsNothing);
    expect(a.cubit.isClosed, false);
  });
  testWidgets(
    'explicit parent Review starts one pending quote before mount without a second Review',
    (tester) async {
      final r = Rig();
      final reply = Completer<Result<ArkQuote, ArkWalletFailure>>();
      r.client.quoteReply = reply;
      final requested = r.cubit
          .load(); // The parent USER action owns this call.
      await tester.pumpWidget(app(r.screen));
      await pumpState(tester);
      expect(r.client.calls, ['quote']);
      expect(find.widgetWithText(BullButton, 'Review'), findsNothing);
      reply.complete(Ok(reviewed(r.cubit.account)));
      await requested;
      await pumpState(tester);
      expect(find.widgetWithText(BullButton, 'Confirm'), findsOneWidget);
      expect(r.client.calls, ['quote']);
    },
  );
  testWidgets(
    'preloaded Review has exact sats fields and is not requoted on mount',
    (tester) async {
      final r = Rig();
      await r.ready();
      await tester.pumpWidget(app(r.screen));
      await pumpState(tester);
      expect(r.client.calls, ['quote']);
      expect(details(tester), {
        'Amount in sats': '1000',
        'Fee (sats)': '100',
        'Net amount (sats)': '900',
        'Payment address or BOLT11 invoice': 'reviewed-destination',
        'Identifier': 'selected-vtxo',
      });
    },
  );
  testWidgets(
    'old same-ID q1 Confirm refuses q2 and duplicate current confirmation retains one original uncertain ID',
    (tester) async {
      final r = Rig();
      await r.ready();
      await tester.pumpWidget(app(r.screen));
      await pumpState(tester);
      final q1 = button(tester, 'Confirm').onPressed;
      await r.ready(amount: 2000);
      await pumpState(tester);
      q1();
      expect(r.ids, 0);
      expect(r.client.calls.where((c) => c == 'submit'), isEmpty);
      final reply = Completer<Result<ArkOperation, ArkWalletFailure>>();
      r.client.submitReply = reply;
      final q2 = button(tester, 'Confirm').onPressed;
      q2();
      q2();
      await pumpState(tester);
      expect(r.ids, 1);
      expect(r.client.calls.where((c) => c == 'submit'), hasLength(1));
      expect(r.cubit.state, isA<ArkOperationSubmitting>());
      reply.complete(const Err(ArkStorageFailure()));
      await pumpLeave(tester);
      expect(
        r.cubit.state,
        isA<ArkOperationUncertain>().having(
          (s) => s.operationId,
          'original attempt',
          'attempt-1',
        ),
      );
      // Unknown outcome: a snackbar says so and Ark reconciles once.
      expect(find.text(uncertainText), findsOneWidget);
      expect(r.reconciles, 1);
      q1();
      q2();
      await r.cubit.load();
      await pumpState(tester);
      expect(r.ids, 1);
      expect(r.client.calls.where((c) => c == 'submit'), hasLength(1));
      expect(r.client.calls.where((c) => c == 'quote'), hasLength(2));
      expect(find.widgetWithText(BullButton, 'Review'), findsNothing);
      expect(find.widgetWithText(BullButton, 'Confirm'), findsNothing);
      expect(
        r.cubit.state,
        isA<ArkOperationUncertain>().having(
          (s) => s.operationId,
          'original attempt',
          'attempt-1',
        ),
      );
      expect(r.reconciles, 1);
      await tester.pump(const Duration(seconds: 4));
    },
  );
  testWidgets(
    'only exact current pre-dispatch Failed can explicitly retry Review',
    (tester) async {
      final r = Rig();
      await r.cubit.load();
      await tester.pumpWidget(app(r.screen));
      await pumpState(tester);
      expect(r.client.calls, ['quote']);
      final old = button(tester, 'Review').onPressed;
      await r.cubit.load();
      await pumpState(tester);
      old();
      expect(r.client.calls, ['quote', 'quote']);
      final reply = Completer<Result<ArkQuote, ArkWalletFailure>>();
      r.client.quoteReply = reply;
      final current = button(tester, 'Review').onPressed;
      current();
      current();
      expect(r.client.calls, ['quote', 'quote', 'quote']);
      reply.complete(Ok(reviewed(r.cubit.account)));
      await pumpState(tester);
      expect(r.ids, 0);
      expect(find.widgetWithText(BullButton, 'Confirm'), findsOneWidget);
    },
  );
  for (final sameAccount in [false, true]) {
    for (final action in ['confirm', 'retry']) {
      testWidgets(
        'old $action refuses replaced owner sameAccount=$sameAccount and disposal',
        (tester) async {
          final a = Rig();
          await tester.pumpWidget(app(a.screen));
          await pumpState(tester);
          a.client.calls.clear();
          final state = action == 'confirm'
              ? ArkOperationReview(reviewed(a.cubit.account))
              : const ArkOperationFailed(ArkServiceUnavailableFailure());
          a.cubit.emit(state);
          await pumpState(tester);
          final label = action == 'confirm' ? 'Confirm' : 'Review';
          final old = button(tester, label).onPressed;
          final original = account();
          final b = Rig(
            owner: sameAccount
                ? original
                : ArkAccountId(
                    parent: original.parent,
                    network: original.network,
                    serverIdentity: 'new-server',
                  ),
          );
          await tester.pumpWidget(app(b.screen));
          await pumpState(tester);
          old();
          await pumpState(tester);
          expect(a.client.calls, isEmpty);
          expect(b.client.calls, isEmpty);
          expect(a.ids + b.ids + a.reconciles + b.reconciles, 0);
          expect(a.cubit.isClosed, false);
          expect(b.cubit.isClosed, false);
          b.cubit.emit(
            action == 'confirm'
                ? ArkOperationReview(reviewed(b.cubit.account))
                : const ArkOperationFailed(ArkServiceUnavailableFailure()),
          );
          await pumpState(tester);
          final disposed = button(tester, label).onPressed;
          await tester.pumpWidget(app(const SizedBox.shrink()));
          disposed();
          await pumpState(tester);
          expect(b.client.calls, isEmpty);
          expect(b.ids + b.reconciles, 0);
          expect(b.cubit.isClosed, false);
        },
      );
    }
  }
  for (final sameAccount in [false, true]) {
    testWidgets(
      'old reconcile refuses replaced owner sameAccount=$sameAccount and disposal',
      (tester) async {
        final a = Rig();
        await tester.pumpWidget(app(a.screen));
        await pumpState(tester);
        a.client.calls.clear();
        final original = account();
        final b = Rig(
          owner: sameAccount
              ? original
              : ArkAccountId(
                  parent: original.parent,
                  network: original.network,
                  serverIdentity: 'new-server',
                ),
        );
        await tester.pumpWidget(app(b.screen));
        await pumpState(tester);
        // The replaced owner's late outcome reconciles nothing.
        a.cubit.emit(const ArkOperationUncertain('original'));
        await pumpLeave(tester);
        expect(find.text(uncertainText), findsNothing);
        expect(a.client.calls, isEmpty);
        expect(b.client.calls, isEmpty);
        expect(a.ids + b.ids + a.reconciles + b.reconciles, 0);
        expect(a.cubit.isClosed, false);
        expect(b.cubit.isClosed, false);
        b.cubit.emit(const ArkOperationUncertain('current'));
        await pumpLeave(tester);
        expect(find.text(uncertainText), findsOneWidget);
        expect(b.reconciles, 1);
        expect(a.reconciles, 0);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpWidget(app(const SizedBox.shrink()));
        b.cubit.emit(const ArkOperationUncertain('disposed'));
        await pumpState(tester);
        expect(b.client.calls, isEmpty);
        expect(b.ids, 0);
        expect(b.reconciles, 1);
        expect(b.cubit.isClosed, false);
      },
    );
  }
  testWidgets(
    'reconcile binds exact original state and current handler without rearming',
    (tester) async {
      final r = Rig();
      await tester.pumpWidget(app(r.screen));
      await pumpState(tester);
      r.client.calls.clear();
      var currentCalls = 0;
      r.cubit.emit(const ArkOperationUncertain('original'));
      // The handler is replaced before the post-frame reconcile runs.
      await tester.pumpWidget(
        app(
          ArkOperationReviewScreen(
            cubit: r.cubit,
            onReconcile: () => currentCalls++,
          ),
        ),
      );
      await pumpLeave(tester);
      expect(currentCalls, 1);
      expect(r.reconciles, 0);
      expect(find.text(uncertainText), findsOneWidget);
      r.cubit.emit(const ArkOperationUncertain('replacement'));
      await pumpState(tester);
      expect(currentCalls, 1);
      expect(r.client.calls, isEmpty);
      expect(r.ids, 0);
      await tester.pump(const Duration(seconds: 4));
    },
  );
  testWidgets('every actual backend status stays non-rearm and is localized', (
    tester,
  ) async {
    final r = Rig();
    await tester.pumpWidget(app(r.screen));
    await pumpState(tester);
    r.client.calls.clear();
    r.cubit.emit(const ArkOperationFailed(ArkServiceUnavailableFailure()));
    await pumpState(tester);
    final oldRetry = button(tester, 'Review').onPressed;
    var mounts = 0;
    for (final entry in {
      for (final status in ArkOperationStatus.values)
        status: statusLabel(status),
    }.entries) {
      for (final locale in ['en', 'fr']) {
        // A fresh page per locale: each one leaves exactly once.
        await tester.pumpWidget(
          app(
            KeyedSubtree(key: ValueKey((entry.key, locale)), child: r.screen),
            language: locale,
          ),
        );
        await pumpState(tester);
        mounts++;
        r.cubit.emit(
          ArkOperationSubmitted(
            ArkOperation(
              id: 'backend-id-$locale',
              kind: ArkOperationKind.renewal,
              status: entry.key,
              chainSource: Uri.parse('http://localhost:3000'),
              configGeneration: 1,
            ),
          ),
        );
        await pumpLeave(tester);
        expect(
          find.text(locale == 'en' ? entry.value.$1 : entry.value.$2),
          findsOneWidget,
        );
        expect(r.reconciles, mounts);
        oldRetry();
        await r.cubit.load();
        await r.cubit.confirm();
        expect(r.client.calls, isEmpty);
        expect(r.ids, 0);
        expect(find.byType(BullButton), findsNothing);
        await tester.pump(const Duration(seconds: 4));
      }
    }
  });
}

const uncertainText =
    'We couldn’t confirm the outcome. Ark is checking it and will update by itself.';

/// Each status's English and French label; a new status fails to compile.
(String, String) statusLabel(ArkOperationStatus status) => switch (status) {
  ArkOperationStatus.prepared => ('Prepared', 'Préparée'),
  ArkOperationStatus.admitted => ('Admitted', 'Admise'),
  ArkOperationStatus.pending => ('Pending', 'En attente'),
  ArkOperationStatus.succeeded => ('Completed', 'Terminée'),
  ArkOperationStatus.failed => ('Failed', 'Échec'),
  ArkOperationStatus.outcomeUnknown => ('Outcome unknown', 'Résultat inconnu'),
  ArkOperationStatus.conflicted => (
    'Conflicting transaction observed',
    'Transaction conflictuelle observée',
  ),
};
