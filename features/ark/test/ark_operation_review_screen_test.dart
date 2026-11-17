import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/ark_repository_impl.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/usecases/confirm_ark_operation_usecase.dart';
import 'package:bull_ark/src/domain/usecases/quote_ark_operation_usecase.dart';
import 'package:bull_ark/src/presentation/ark_operation_cubit.dart';
import 'package:bull_ark/src/ui/ark_operation_review_screen.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullDetailsTable, BullDetailsTableItem, SizedBox;
import 'package:flutter_test/flutter_test.dart';
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
  Rig({ArkAccountId? owner}) {
    final repository = ArkRepositoryImpl(client);
    cubit = ArkOperationCubit(
      QuoteArkOperationUsecase(repository, Preferences()),
      ConfirmArkOperationUsecase(repository, Preferences()),
      () => 'attempt-${++ids}',
      account: owner ?? account(),
      request: ArkQuoteRequest.renewal(ids: ['selected-vtxo']),
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

void main() {
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
        'Ark address or BOLT11 invoice': 'reviewed-destination',
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
      await pumpState(tester);
      expect(
        r.cubit.state,
        isA<ArkOperationUncertain>().having(
          (s) => s.operationId,
          'original attempt',
          'attempt-1',
        ),
      );
      q1();
      q2();
      await r.cubit.load();
      await pumpState(tester);
      expect(r.ids, 1);
      expect(r.client.calls.where((c) => c == 'quote'), hasLength(2));
      expect(find.widgetWithText(BullButton, 'Review'), findsNothing);
      expect(details(tester)['Identifier'], 'attempt-1');
      button(tester, 'Refresh').onPressed();
      expect(r.reconciles, 1);
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
    for (final action in ['confirm', 'retry', 'reconcile']) {
      testWidgets(
        'old $action refuses replaced owner sameAccount=$sameAccount and disposal',
        (tester) async {
          final a = Rig();
          await tester.pumpWidget(app(a.screen));
          await pumpState(tester);
          a.client.calls.clear();
          final state = switch (action) {
            'confirm' => ArkOperationReview(reviewed(a.cubit.account)),
            'retry' => const ArkOperationFailed(ArkServiceUnavailableFailure()),
            _ => const ArkOperationUncertain('original'),
          };
          a.cubit.emit(state);
          await pumpState(tester);
          final label = switch (action) {
            'confirm' => 'Confirm',
            'retry' => 'Review',
            _ => 'Refresh',
          };
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
          b.cubit.emit(switch (action) {
            'confirm' => ArkOperationReview(reviewed(b.cubit.account)),
            'retry' => const ArkOperationFailed(ArkServiceUnavailableFailure()),
            _ => const ArkOperationUncertain('current'),
          });
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
  testWidgets(
    'reconcile binds exact original state and current handler without rearming',
    (tester) async {
      final r = Rig();
      await tester.pumpWidget(app(r.screen));
      await pumpState(tester);
      r.client.calls.clear();
      r.cubit.emit(const ArkOperationUncertain('original'));
      await pumpState(tester);
      final old = button(tester, 'Refresh').onPressed;
      var currentCalls = 0;
      await tester.pumpWidget(
        app(
          ArkOperationReviewScreen(
            cubit: r.cubit,
            onReconcile: () => currentCalls++,
          ),
        ),
      );
      old();
      expect(currentCalls, 1);
      expect(r.reconciles, 0);
      r.cubit.emit(const ArkOperationUncertain('replacement'));
      await pumpState(tester);
      old();
      expect(currentCalls, 1);
      expect(r.client.calls, isEmpty);
      expect(r.ids, 0);
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
    final labels = {
      ArkOperationStatus.prepared: ('Prepared', 'Préparée'),
      ArkOperationStatus.admitted: ('Admitted', 'Admise'),
      ArkOperationStatus.pending: ('Pending', 'En attente'),
      ArkOperationStatus.succeeded: ('Completed', 'Terminée'),
      ArkOperationStatus.failed: ('Failed', 'Échec'),
      ArkOperationStatus.outcomeUnknown: (
        'Outcome unknown',
        'Résultat inconnu',
      ),
      ArkOperationStatus.conflicted: (
        'Conflicting transaction observed',
        'Transaction conflictuelle observée',
      ),
    };
    for (final entry in labels.entries) {
      r.cubit.emit(
        ArkOperationSubmitted(
          ArkOperation(
            id: 'backend-id',
            kind: ArkOperationKind.renewal,
            status: entry.key,
            chainSource: Uri.parse('http://localhost:3000'),
            configGeneration: 1,
          ),
        ),
      );
      for (final locale in ['en', 'fr']) {
        await tester.pumpWidget(app(r.screen, language: locale));
        await pumpState(tester);
        expect(
          details(tester).values,
          containsAll([
            'backend-id',
            locale == 'en' ? entry.value.$1 : entry.value.$2,
          ]),
        );
        oldRetry();
        await r.cubit.load();
        await r.cubit.confirm();
        expect(r.client.calls, isEmpty);
        expect(r.ids, 0);
        expect(
          tester.widgetList<BullButton>(find.byType(BullButton)),
          hasLength(1),
        );
        expect(
          find.widgetWithText(
            BullButton,
            locale == 'en' ? 'Confirm' : 'Confirmer',
          ),
          findsNothing,
        );
      }
    }
  });
}
