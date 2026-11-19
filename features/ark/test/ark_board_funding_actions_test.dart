import 'package:ark/ark.dart';
import 'package:bull_ark/src/ui/ark_board_screen.dart';
import 'package:bull_ark/src/presentation/ark_board_cubit.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullTopBar,
        BullAmountSnapshot,
        ModalRoute,
        Navigator,
        BullDialog,
        BullText;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_board_screen_test.dart' show Rig, button;
import 'ark_board_journey_test.dart' show prepared;
import 'ark_information_widget_test.dart' show app, config;

void main() {
  final txid = prepared().unsignedTxid;
  ArkOperation operation({
    String? reference,
    ArkOperationStatus status = ArkOperationStatus.pending,
  }) => ArkOperation(
    id: prepared().operationId,
    kind: ArkOperationKind.board,
    status: status,
    nativeReference: reference,
    chainSource: config().primaryEsploraUrl,
    configGeneration: 2,
  );

  testWidgets(
    'funding options copy the real full ID and configured network link; Done is navigation only',
    (tester) async {
      final rig = Rig();
      final copied = <String>[];
      final opened = <Uri>[];
      var done = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final uri = Uri.parse('http://127.0.0.1:3000/tx/$txid');
      rig.funding.confirmed = Ok(operation(reference: txid));
      await rig.cubit.prepare(Sats.fromInt(1000));
      await tester.pumpWidget(
        app(
          ArkBoardScreen(
            cubit: rig.cubit,
            onReconcile: () {},
            onDone: () => done++,
            fundingExplorer: (account, id) {
              expect(account, rig.cubit.config.id);
              expect(id, txid);
              return uri;
            },
            onOpenExplorer: (link) async => opened.add(link),
          ),
        ),
      );
      await tester.pumpAndSettle();
      button(tester, 'Confirm').onPressed();
      await tester.pumpAndSettle();
      expect(rig.cubit.state, isA<ArkBoardSubmitted>());
      expect(tester.widget<BullTopBar>(find.byType(BullTopBar)).onBack, isNull);
      await tester.tap(
        find.text(
          '${txid.substring(0, 16)}…${txid.substring(txid.length - 12)}',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(txid), findsOneWidget);
      final copy = find.widgetWithText(BullButton, 'Copy transaction ID').last;
      await tester.ensureVisible(copy);
      await tester.tap(copy);
      await tester.pump();
      expect(copied, [txid]);
      final copyLink = find.widgetWithText(BullButton, 'Copy link');
      await tester.ensureVisible(copyLink);
      await tester.tap(copyLink);
      await tester.pump();
      expect(copied, [txid, uri.toString()]);
      final explore = find.widgetWithText(BullButton, 'View in explorer');
      await tester.ensureVisible(explore);
      await tester.tap(explore);
      await tester.pump();
      expect(opened, [uri]);
      final before = List<String>.of(rig.funding.calls);
      // Dismiss modal; the second Done belongs to the submitted page.
      await tester.tap(find.widgetWithText(BullButton, 'Done').last);
      await tester.pumpAndSettle();
      button(tester, 'Done').onPressed();
      expect(done, 1);
      expect(rig.funding.calls, before);
      expect(rig.cubit.state, isA<ArkBoardSubmitted>());
      // Finish the copy toast's auto-dismiss timer and exit animation.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );

  for (final reference in <String?>[
    null,
    'operation-id',
    'not-a-funding-txid',
  ]) {
    testWidgets(
      'missing or malformed funding identity stays unavailable: $reference',
      (tester) async {
        final rig = Rig();
        rig.funding.confirmed = Ok(operation(reference: reference));
        await rig.cubit.prepare(Sats.fromInt(1000));
        await rig.cubit.confirm();
        await tester.pumpWidget(app(rig.screen));
        await tester.pumpAndSettle();
        expect(find.text('Boarding started'), findsNothing);
        expect(find.text('Funding transaction unavailable'), findsOneWidget);
        expect(
          find.widgetWithText(BullButton, 'Copy transaction ID'),
          findsNothing,
        );
        expect(
          find.widgetWithText(BullButton, 'View in explorer'),
          findsNothing,
        );
      },
    );
  }

  testWidgets('absent explorer capability never fabricates a mainnet link', (
    tester,
  ) async {
    final rig = Rig();
    rig.funding.confirmed = Ok(operation(reference: txid));
    await rig.cubit.prepare(Sats.fromInt(1000));
    await rig.cubit.confirm();
    await tester.pumpWidget(app(rig.screen));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('${txid.substring(0, 16)}…${txid.substring(txid.length - 12)}'),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(BullButton, 'Copy link'), findsNothing);
    expect(find.widgetWithText(BullButton, 'View in explorer'), findsNothing);
  });

  testWidgets('review financial amounts respect amount privacy', (
    tester,
  ) async {
    final rig = Rig();
    await rig.cubit.prepare(Sats.fromInt(1000));
    await tester.pumpWidget(
      app(
        rig.screen,
        amountPreferences: const BullAmountSnapshot(
          unit: BitcoinUnit.sats,
          hideAmounts: true,
          isReady: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final value in [
      '1,000 sats',
      '100 sats',
      '10 sats',
      '1,100 sats',
      '990 sats',
    ]) {
      expect(find.text(value), findsNothing);
    }
    expect(button(tester, 'Confirm').disabled, isFalse);
  });
  for (final status in [
    ArkOperationStatus.failed,
    ArkOperationStatus.outcomeUnknown,
    ArkOperationStatus.conflicted,
  ]) {
    testWidgets('submitted status $status cannot claim boarding started', (
      tester,
    ) async {
      final rig = Rig();
      rig.funding.confirmed = Ok(operation(reference: txid, status: status));
      await rig.cubit.prepare(Sats.fromInt(1000));
      await rig.cubit.confirm();
      await tester.pumpWidget(app(rig.screen));
      await tester.pumpAndSettle();
      expect(find.text('Boarding started'), findsNothing);
      expect(find.text('Boarding status needs verification'), findsOneWidget);
    });
  }

  testWidgets(
    'dismissed dialog A cannot act on dialog B while its Submitted owner stays mounted',
    (tester) async {
      final rig = Rig();
      final copied = <String>[];
      final opened = <Uri>[];
      var done = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final uri = Uri.parse('http://localhost:3000/tx/$txid');
      rig.funding.confirmed = Ok(operation(reference: txid));
      await rig.cubit.prepare(Sats.fromInt(1000));
      await rig.cubit.confirm();
      final submitted = rig.cubit.state;
      await tester.pumpWidget(
        app(
          ArkBoardScreen(
            cubit: rig.cubit,
            onReconcile: () {},
            onDone: () => done++,
            fundingExplorer: (_, _) => uri,
            onOpenExplorer: (uri) async => opened.add(uri),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> openDialog() async {
        await tester.tap(
          find.text(
            '${txid.substring(0, 16)}…${txid.substring(txid.length - 12)}',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(txid), findsOneWidget);
      }

      BullButton modalButton(String label) => tester.widget<BullButton>(
        find.widgetWithText(BullButton, label).last,
      );
      await openDialog();
      final copyA = modalButton('Copy transaction ID').onPressed;
      final copyLinkA = modalButton('Copy link').onPressed;
      final openA = modalButton('View in explorer').onPressed;
      final doneA = modalButton('Done').onPressed;
      final contextA = tester.element(find.text(txid));
      final routeA = ModalRoute.of(contextA);
      Navigator.of(contextA).pop();
      await tester.pumpAndSettle();
      expect(contextA.mounted, isFalse);
      expect(routeA?.isActive, isFalse);
      expect(rig.cubit.state, same(submitted));
      expect(find.byType(ArkBoardScreen), findsOneWidget);
      await openDialog();
      final routeB = ModalRoute.of(tester.element(find.text(txid)));
      expect(routeB?.isCurrent, isTrue);
      expect(routeB, isNot(same(routeA)));
      final before = List<String>.of(rig.funding.calls);
      copyA();
      copyLinkA();
      openA();
      doneA();
      await tester.pumpAndSettle();
      expect(copied, isEmpty);
      expect(opened, isEmpty);
      expect(done, 0);
      expect(routeB?.isCurrent, isTrue, reason: 'Done A must not pop dialog B');
      expect(find.text(txid), findsOneWidget);
      expect(rig.cubit.state, same(submitted));
      expect(tester.takeException(), isNull);
      final coveredCopy = modalButton('Copy transaction ID').onPressed;
      final coveredLink = modalButton('Copy link').onPressed;
      final coveredOpen = modalButton('View in explorer').onPressed;
      final coveredDone = modalButton('Done').onPressed;
      final cover = BullDialog.show<void>(
        context: tester.element(find.text(txid)),
        builder: (_) => const BullText('Covering route'),
      );
      await tester.pumpAndSettle();
      expect(routeB?.isCurrent, isFalse);
      final coveringContext = tester.element(find.text('Covering route'));
      final coveringRoute = ModalRoute.of(coveringContext);
      coveredCopy();
      coveredLink();
      coveredOpen();
      coveredDone();
      await tester.pumpAndSettle();
      expect(copied, isEmpty);
      expect(opened, isEmpty);
      expect(coveringRoute?.isCurrent, isTrue);
      Navigator.of(coveringContext).pop();
      await cover;
      await tester.pumpAndSettle();
      expect(routeB?.isCurrent, isTrue);
      modalButton('Copy transaction ID').onPressed();
      await tester.pump();
      modalButton('Copy link').onPressed();
      await tester.pump();
      modalButton('View in explorer').onPressed();
      await tester.pump();
      expect(copied, [txid, uri.toString()]);
      expect(opened, [uri]);
      modalButton('Done').onPressed();
      await tester.pumpAndSettle();
      expect(routeB?.isActive, isFalse);
      expect(find.text(txid), findsNothing);
      expect(find.byType(ArkBoardScreen), findsOneWidget);
      expect(done, 0);
      expect(rig.funding.calls, before);
      // Finish the copy toast's auto-dismiss timer and exit animation.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('replacing the owner retires the old funding content', (
    tester,
  ) async {
    final first = Rig();
    final second = Rig();
    for (final rig in [first, second]) {
      rig.funding.confirmed = Ok(operation(reference: txid));
      await rig.cubit.prepare(Sats.fromInt(1000));
      await rig.cubit.confirm();
    }
    await tester.pumpWidget(app(first.screen));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('${txid.substring(0, 16)}…${txid.substring(txid.length - 12)}'),
    );
    await tester.pumpAndSettle();
    final route = ModalRoute.of(tester.element(find.text(txid)));
    expect(route?.isCurrent, isTrue);
    await tester.pumpWidget(app(second.screen));
    await tester.pumpAndSettle();
    expect(route?.isActive, isFalse);
    expect(find.text(txid), findsNothing);
    expect(find.byType(ArkBoardScreen), findsOneWidget);
    expect(second.cubit.state, isA<ArkBoardSubmitted>());
    expect(tester.takeException(), isNull);
  });
}
