import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/ark_repository_impl.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/usecases/confirm_ark_operation_usecase.dart';
import 'package:bull_ark/src/domain/usecases/quote_ark_operation_usecase.dart';
import 'package:bull_ark/src/presentation/ark_operation_cubit.dart';
import 'package:bull_ark/src/ui/ark_exit_request_screen.dart';
import 'package:bull_ark/src/ui/ark_exit_start_sheet.dart';
import 'package:bull_ark/src/ui/ark_hold_button.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullCheckbox,
        BullInputText,
        BullPickerRow,
        BullSegmented,
        SizedBox;
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app;
import 'ark_operations_test.dart' show account, Preferences;
import 'fake_ark_client.dart';

ArkSnapshot inventory({bool stale = false, bool complete = true}) =>
    ArkSnapshot(
      account: account(),
      revision: 1,
      observedAt: DateTime.utc(2026),
      stale: stale,
      tipHeight: 100,
      recovery: ArkRecoveryStatus.complete,
      exits: ArkExitStatus.none,
      vtxoCompleteness: complete
          ? ArkSectionCompleteness.complete
          : ArkSectionCompleteness.unknown,
      vtxos: [
        ArkVtxo(
          id: 'selected',
          amount: Sats.fromInt(1000),
          expiryHeight: 200,
          state: ArkVtxoState.spendable,
        ),
        ArkVtxo(
          id: 'locked',
          amount: Sats.fromInt(1000),
          expiryHeight: 200,
          state: ArkVtxoState.locked,
        ),
      ],
      exitDetails: [
        ArkExit(
          id: 'claimable',
          amount: Sats.fromInt(1000),
          status: ArkExitStatus.claimable,
        ),
      ],
    );

/// Answers every exit request with a quote for exactly that request: 300 sats
/// to broadcast, 40 to claim, from 1,000 sats per VTXO.
class ExitClient extends FakeArkClient {
  final requests = <ArkEmergencyExitQuoteRequest>[];
  bool refuse = false;

  /// Refuses every quote with this failure.
  ArkWalletFailure? failure;

  /// The confirmed fee reserve each quote observes; null observes none.
  int? reserve;

  ExitClient() {
    quoted = const Err(ArkUnavailableFailure());
    submitted = Ok(
      ArkOperation(
        id: 'attempt',
        kind: ArkOperationKind.emergencyExit,
        status: ArkOperationStatus.pending,
        chainSource: Uri.parse('http://localhost:3000'),
        configGeneration: 1,
      ),
    );
  }

  List<String> get submits => calls.where((c) => c == 'submit').toList();

  @override
  Future<Result<ArkQuote, ArkWalletFailure>> quote(
    ArkAccountId account,
    ArkQuoteRequest request,
  ) async {
    if (failure case final failure?) return Err(failure);
    if (request is! ArkEmergencyExitQuoteRequest || refuse) {
      return const Err(ArkUnavailableFailure());
    }
    requests.add(request);
    final amount = 1000 * request.ids.length;
    return Ok(
      ArkQuote(
        id: 'quote-${requests.length}',
        account: account,
        generation: 1,
        chainSource: Uri.parse('http://localhost:3000'),
        configGeneration: 1,
        kind: ArkOperationKind.emergencyExit,
        amount: Sats.fromInt(amount),
        fee: Sats.fromInt(300),
        net: Sats.fromInt(amount - 40),
        claimFee: Sats.fromInt(40),
        selectedIds: request.ids,
        destination: request.destination,
        observedTip: 100,
        validUntil: DateTime.utc(2030),
        feeRate: FeeRate(5),
        maxClaimFee: Sats.fromInt(80),
        confirmedReserveExposure: switch (reserve) {
          final sats? => Sats.fromInt(sats),
          null => null,
        },
      ),
    );
  }
}

ArkOperationCubit Function(ArkQuoteRequest) quotes(ExitClient client) {
  final repository = ArkRepositoryImpl(client);
  return (request) => ArkOperationCubit(
    QuoteArkOperationUsecase(repository, Preferences()),
    ConfirmArkOperationUsecase(repository, Preferences()),
    () => 'attempt',
    account: account(),
    request: request,
  );
}

const secureAddress = 'bcrt1qsecurewalletaddress9';

Future<Result<String, ArkFailure>> secure() async => const Ok(secureAddress);

ArkExitRequestScreen exitScreen(
  ExitClient client, {
  ArkSnapshot? snapshot,
  Future<Result<String, ArkFailure>> Function()? secureBitcoinAddress = secure,
  List<ArkExitOutcome>? started,
}) => ArkExitRequestScreen(
  snapshot: snapshot ?? inventory(),
  onReview: (_) => fail('An exit never opens the claim review'),
  quote: quotes(client),
  secureBitcoinAddress: secureBitcoinAddress,
  onStarted: started?.add,
);

BullButton review(WidgetTester tester) =>
    tester.widget<BullButton>(find.widgetWithText(BullButton, 'Review exit'));
BullButton reviewClaim(WidgetTester tester) =>
    tester.widget<BullButton>(find.widgetWithText(BullButton, 'Review claim'));

ArkHoldButton holdButton(WidgetTester tester) =>
    tester.widget<ArkHoldButton>(find.byType(ArkHoldButton));

Future<void> openSheet(WidgetTester tester) async {
  review(tester).onPressed();
  await tester.pumpAndSettle();
}

/// Holds the start button for [held], then lets go.
Future<void> hold(WidgetTester tester, {Duration? release}) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(ArkHoldButton)),
  );
  final held = release ?? const Duration(seconds: 2);
  for (var waited = Duration.zero; waited < held; waited += _step) {
    await tester.pump(_step);
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

const _step = Duration(milliseconds: 100);
Future<void> edit(WidgetTester tester, String hint, String value) async {
  tester
      .widgetList<BullInputText>(find.byType(BullInputText))
      .singleWhere((input) => input.hint == hint)
      .onChanged(value);
  await tester.pump();
}

Future<void> fill(WidgetTester tester) async {
  await edit(tester, 'On-chain return address', 'bcrt1-return');
  await edit(tester, 'Maximum claim fee (sats)', '500');
}

void main() {
  testWidgets('the choose screen shows the automatic exit estimate', (
    tester,
  ) async {
    final client = ExitClient();
    await tester.pumpWidget(app(exitScreen(client)));
    await tester.pumpAndSettle();
    // No fee field to fill: the native wallet picks the rate.
    expect(find.byType(BullInputText), findsNothing);
    final request = client.requests.single;
    expect(request.ids, ['selected']);
    expect(request.destination, isNull);
    expect(request.feeRate, isNull);
    expect(request.maxClaimFee, isNull);
    expect(find.text('340 sats'), findsOneWidget);
    expect(find.text('300 sats'), findsOneWidget);
    expect(find.text('40 sats'), findsOneWidget);
    expect(find.text('960 sats'), findsOneWidget);
    expect(review(tester).disabled, false);
  });

  testWidgets('a refused estimate keeps the exit from being reviewed', (
    tester,
  ) async {
    final client = ExitClient()..refuse = true;
    await tester.pumpWidget(app(exitScreen(client)));
    await tester.pumpAndSettle();
    expect(review(tester).disabled, true);
    await openSheet(tester);
    expect(find.byType(ArkExitStartSheet), findsNothing);
  });

  testWidgets('a refused estimate says why and cannot be reviewed', (
    tester,
  ) async {
    final client = ExitClient()..failure = const ArkInsufficientFundsFailure();
    await tester.pumpWidget(app(exitScreen(client)));
    await tester.pumpAndSettle();
    expect(find.text('Insufficient funds, including fees.'), findsOneWidget);
    expect(find.textContaining('fee reserve'), findsNothing);
    expect(review(tester).disabled, true);
  });

  testWidgets('selected scope estimates only the chosen eligible ids', (
    tester,
  ) async {
    final client = ExitClient();
    await tester.pumpWidget(app(exitScreen(client)));
    await tester.pumpAndSettle();
    tester
        .widget<BullSegmented>(find.byType(BullSegmented))
        .onSelected('Selected VTXOs');
    await tester.pumpAndSettle();
    expect(find.byType(BullCheckbox), findsOneWidget);
    expect(review(tester).disabled, true);
    final select = tester
        .widget<BullCheckbox>(find.byType(BullCheckbox))
        .onChanged;
    if (select == null) fail('Selection callback is required');
    select(true);
    await tester.pumpAndSettle();
    expect(review(tester).disabled, false);
    expect(client.requests.last.ids, ['selected']);
  });

  testWidgets('captured selection cannot edit a replacement observation', (
    tester,
  ) async {
    final client = ExitClient();
    await tester.pumpWidget(app(exitScreen(client)));
    tester
        .widget<BullSegmented>(find.byType(BullSegmented))
        .onSelected('Selected VTXOs');
    await tester.pump();
    final old = tester
        .widget<BullCheckbox>(find.byType(BullCheckbox))
        .onChanged;
    await tester.pumpWidget(
      app(exitScreen(client, snapshot: inventory(stale: true))),
    );
    if (old == null) fail('Selection callback is required');
    old(true);
    await tester.pump();
    expect(
      tester.widget<BullCheckbox>(find.byType(BullCheckbox)).checked,
      false,
    );
  });

  testWidgets(
    'the sheet quotes the Secure Bitcoin address and holding starts the exit',
    (tester) async {
      final client = ExitClient();
      final started = <ArkExitOutcome>[];
      await tester.pumpWidget(app(exitScreen(client, started: started)));
      await tester.pumpAndSettle();
      await openSheet(tester);
      expect(find.text('Start emergency exit'), findsOneWidget);
      expect(find.text('All eligible · 1 VTXO'), findsOneWidget);
      expect(find.text('bcrt1qse…ress9'), findsOneWidget);
      final request = client.requests.last;
      expect(request.destination, secureAddress);
      expect(request.feeRate, isNull);
      expect(client.submits, isEmpty);
      await hold(tester);
      expect(client.submits, hasLength(1));
      expect(find.byType(ArkExitStartSheet), findsNothing);
      expect(started, [ArkExitOutcome.started]);
      // A started exit cannot be reviewed again from this form.
      expect(review(tester).disabled, true);
    },
  );

  testWidgets('an empty reserve still starts: Secure Bitcoin pays later', (
    tester,
  ) async {
    final client = ExitClient()..reserve = 0;
    final started = <ArkExitOutcome>[];
    await tester.pumpWidget(app(exitScreen(client, started: started)));
    await tester.pumpAndSettle();
    await openSheet(tester);
    expect(find.textContaining('fee reserve'), findsNothing);
    await hold(tester);
    expect(client.submits, hasLength(1));
    expect(started, [ArkExitOutcome.started]);
  });

  testWidgets('holding prices the exit again and starts that fresh quote', (
    tester,
  ) async {
    final client = ExitClient();
    await tester.pumpWidget(app(exitScreen(client)));
    await tester.pumpAndSettle();
    await openSheet(tester);
    final quotedBeforeHold = client.requests.length;
    await hold(tester);
    // One more quote, for the same VTXOs and destination, right at the hold.
    expect(client.requests, hasLength(quotedBeforeHold + 1));
    expect(client.requests.last.destination, secureAddress);
    final confirmed = client.arguments
        .whereType<(ArkAccountId, ArkSubmission)>()
        .map((call) => call.$2)
        .whereType<ArkConfirmQuote>()
        .single;
    expect(confirmed.quoteId, 'quote-${client.requests.length}');
  });

  testWidgets('another wallet quotes the typed address once typing stops', (
    tester,
  ) async {
    final client = ExitClient();
    await tester.pumpWidget(app(exitScreen(client)));
    await tester.pumpAndSettle();
    await openSheet(tester);
    tester
        .widget<BullPickerRow>(
          find.widgetWithText(BullPickerRow, 'Another Bitcoin wallet'),
        )
        .onPressed
        ?.call();
    await tester.pumpAndSettle();
    // Nothing typed yet: nothing to start.
    expect(holdButton(tester).onConfirmed, isNull);
    final quoted = client.requests.length;
    await edit(tester, 'Bitcoin address', 'bcrt1qother');
    expect(client.requests, hasLength(quoted));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(client.requests.last.destination, 'bcrt1qother');
    expect(holdButton(tester).onConfirmed, isNotNull);
  });

  testWidgets(
    'without a Secure Bitcoin wallet only a typed address is offered',
    (tester) async {
      final client = ExitClient();
      await tester.pumpWidget(
        app(exitScreen(client, secureBitcoinAddress: null)),
      );
      await tester.pumpAndSettle();
      await openSheet(tester);
      expect(find.text('Secure Bitcoin wallet'), findsNothing);
      expect(find.byType(BullPickerRow), findsOneWidget);
      expect(holdButton(tester).onConfirmed, isNull);
    },
  );

  testWidgets('an unavailable Secure Bitcoin address offers nothing to start', (
    tester,
  ) async {
    final client = ExitClient();
    await tester.pumpWidget(
      app(
        exitScreen(
          client,
          secureBitcoinAddress: () async =>
              const Err(ArkServiceUnavailableFailure()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openSheet(tester);
    expect(
      find.text('Couldn’t get an address from your Secure Bitcoin wallet.'),
      findsOneWidget,
    );
    expect(client.requests.where((r) => r.destination != null), isEmpty);
    expect(holdButton(tester).onConfirmed, isNull);
  });

  testWidgets('releasing the hold early or cancelling never starts', (
    tester,
  ) async {
    final client = ExitClient();
    await tester.pumpWidget(app(exitScreen(client)));
    await tester.pumpAndSettle();
    await openSheet(tester);
    await hold(tester, release: const Duration(milliseconds: 500));
    expect(client.submits, isEmpty);
    expect(find.text('Keep holding until the bar fills.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(ArkExitStartSheet), findsNothing);
    expect(client.submits, isEmpty);
    expect(review(tester).disabled, false);
  });

  testWidgets('hold is also a named semantics button', (tester) async {
    final semantics = tester.ensureSemantics();
    final client = ExitClient();
    await tester.pumpWidget(app(exitScreen(client)));
    await tester.pumpAndSettle();
    await openSheet(tester);
    final node = find.bySemanticsLabel('Hold to start exit');
    expect(node, findsOneWidget);
    expect(
      tester.getSemantics(node),
      matchesSemantics(
        label: 'Hold to start exit',
        hint: 'Press and hold for a few seconds.',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    final semanticsNode = tester.getSemantics(node);
    semanticsNode.owner?.performAction(semanticsNode.id, SemanticsAction.tap);
    await tester.pumpAndSettle();
    expect(client.submits, hasLength(1));
    semantics.dispose();
  });

  testWidgets(
    'claim uses only supplied currently claimable ids with no automatic submission',
    (tester) async {
      final requests = <ArkQuoteRequest>[];
      await tester.pumpWidget(
        app(
          ArkExitRequestScreen(
            snapshot: inventory(),
            claimIds: const ['claimable'],
            onReview: requests.add,
          ),
        ),
      );
      await fill(tester);
      expect(find.byType(ArkHoldButton), findsNothing);
      reviewClaim(tester).onPressed();
      final request = requests.single as ArkClaimQuoteRequest;
      expect(request.ids, ['claimable']);
      expect(request.maxFee, Sats.fromInt(500));
    },
  );
  for (final snapshot in [inventory(stale: true), inventory(complete: false)]) {
    testWidgets(
      'stale or incomplete inventory refuses exit ${snapshot.stale}',
      (tester) async {
        final client = ExitClient();
        await tester.pumpWidget(app(exitScreen(client, snapshot: snapshot)));
        await tester.pumpAndSettle();
        expect(client.requests, isEmpty);
        expect(review(tester).disabled, true);
        await openSheet(tester);
        expect(find.byType(ArkExitStartSheet), findsNothing);
      },
    );
  }

  testWidgets(
    'old callbacks cannot cross a replaced snapshot or disposed form',
    (tester) async {
      final client = ExitClient();
      await tester.pumpWidget(app(exitScreen(client)));
      await tester.pumpAndSettle();
      final old = review(tester).onPressed;
      await tester.pumpWidget(
        app(exitScreen(client, snapshot: inventory(stale: true))),
      );
      old();
      await tester.pumpAndSettle();
      expect(find.byType(ArkExitStartSheet), findsNothing);
      await tester.pumpWidget(app(const SizedBox.shrink()));
      old();
      await tester.pumpAndSettle();
      expect(find.byType(ArkExitStartSheet), findsNothing);
    },
  );

  testWidgets('an empty selection explains why review is disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(ArkExitRequestScreen(snapshot: inventory(), onReview: (_) {})),
    );
    tester
        .widget<BullSegmented>(find.byType(BullSegmented))
        .onSelected('Selected VTXOs');
    await tester.pump();
    expect(find.text('Choose at least one VTXO.'), findsOneWidget);
    expect(find.text('Expires in 100 blocks'), findsOneWidget);
    await tester.tap(find.text('Select all'));
    await tester.pump();
    expect(find.text('Choose at least one VTXO.'), findsNothing);
    expect(find.text('Clear all'), findsOneWidget);
  });
}
