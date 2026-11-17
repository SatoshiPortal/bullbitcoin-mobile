import 'package:ark/ark.dart';
import 'package:bull_ark/src/presentation/ark_receive_cubit.dart';
import 'package:bull_ark/src/ui/ark_receive_screen.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullQrCode,
        BullDetailsTable,
        BullDetailsTableItem,
        SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_receive_flow_test.dart' show app, controller, DelayedReceive;
import 'ark_operations_test.dart' show account;
import 'fake_ark_client.dart';

Future<void> frame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

BullButton share(WidgetTester tester) {
  final found = find.widgetWithText(BullButton, 'Share');
  expect(
    found,
    findsOneWidget,
    reason: 'Ready exposes an explicit Share action',
  );
  return tester.widget<BullButton>(found);
}

ArkReceiveDestination payload({
  ArkDestinationKind kind = ArkDestinationKind.ark,
  String value = 'public-request',
}) => ArkReceiveDestination(kind: kind, value: value);
ArkReceiveCubit ready(FakeArkClient client, {ArkAccountId? owner}) {
  final cubit = controller(client, id: owner);
  addTearDown(() async {
    if (!cubit.isClosed) await cubit.close();
  });
  return cubit;
}

void main() {
  for (final kind in [ArkDestinationKind.ark, ArkDestinationKind.bolt11]) {
    testWidgets(
      'Ready $kind forwards exact displayed copied QR text only on explicit tap',
      (tester) async {
        final destination = payload(kind: kind, value: ' public-$kind ');
        final client = FakeArkClient()..destination = Ok(destination);
        final cubit = ready(client);
        await cubit.request(
          lightning: kind == ArkDestinationKind.bolt11,
          amount: '1000',
        );
        final received = <String>[];
        final page = ArkReceiveScreen(cubit: cubit, onShare: received.add);
        await tester.pumpWidget(app(page));
        await frame(tester);
        await tester.pumpWidget(app(page));
        await frame(tester);
        expect(received, isEmpty);
        expect(client.calls, ['receive']);
        final row = tester
            .widget<BullDetailsTable>(find.byType(BullDetailsTable))
            .items
            .whereType<BullDetailsTableItem>()
            .first;
        expect(row.displayValue, destination.value);
        expect(row.copyValue, destination.value);
        expect(
          tester.widget<BullQrCode>(find.byType(BullQrCode)).data,
          destination.value,
        );
        expect(share(tester).disabled, false);
        share(tester).onPressed();
        share(tester).onPressed();
        expect(received, [destination.value, destination.value]);
        expect(client.calls, ['receive']);
        expect(cubit.state, isA<ArkReceiveReady>());
      },
    );
  }
  testWidgets(
    'missing and removed capability stay disabled and invalidate an old action',
    (tester) async {
      final client = FakeArkClient()..destination = Ok(payload());
      final cubit = ready(client);
      await cubit.request(lightning: false, amount: '');
      final received = <String>[];
      await tester.pumpWidget(app(ArkReceiveScreen(cubit: cubit)));
      await frame(tester);
      expect(share(tester).disabled, true);
      share(tester).onPressed();
      expect(
        find.text('This Ark action is unavailable in this build.'),
        findsOneWidget,
      );
      await tester.pumpWidget(
        app(ArkReceiveScreen(cubit: cubit, onShare: received.add)),
      );
      await frame(tester);
      final old = share(tester).onPressed;
      await tester.pumpWidget(app(ArkReceiveScreen(cubit: cubit)));
      await frame(tester);
      old();
      expect(received, isEmpty);
      expect(client.calls, ['receive']);
    },
  );
  testWidgets(
    'whitespace is a real DTO but unavailable for sharing, not a backend outage',
    (tester) async {
      final client = FakeArkClient()..destination = Ok(payload(value: ' \t '));
      final cubit = ready(client);
      await cubit.request(lightning: false, amount: '');
      final received = <String>[];
      await tester.pumpWidget(
        app(ArkReceiveScreen(cubit: cubit, onShare: received.add)),
      );
      await frame(tester);
      expect(share(tester).disabled, true);
      share(tester).onPressed();
      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.text('Ark is unavailable. Try again.'), findsNothing);
      expect(received, isEmpty);
      expect(client.calls, ['receive']);
    },
  );
  testWidgets(
    'Editing Loading and failed request never share or request implicitly',
    (tester) async {
      final client = DelayedReceive();
      final cubit = ready(client);
      final received = <String>[];
      await tester.pumpWidget(
        app(ArkReceiveScreen(cubit: cubit, onShare: received.add)),
      );
      await frame(tester);
      expect(client.calls, isEmpty);
      expect(find.widgetWithText(BullButton, 'Share'), findsNothing);
      final pending = cubit.request(lightning: false, amount: '');
      await frame(tester);
      expect(find.widgetWithText(BullButton, 'Share'), findsNothing);
      client.reply.complete(const Err(ArkUnavailableFailure()));
      await pending;
      await frame(tester);
      expect(find.widgetWithText(BullButton, 'Share'), findsNothing);
      expect(received, isEmpty);
      expect(client.calls, ['receive']);
    },
  );
  testWidgets(
    'old Ready refuses edit pending request and new same-payload request epoch',
    (tester) async {
      final client = DelayedReceive();
      final cubit = ready(client);
      final received = <String>[];
      final destination = payload();
      final original = ArkReceiveReady(destination);
      cubit.emit(original);
      await tester.pumpWidget(
        app(ArkReceiveScreen(cubit: cubit, onShare: received.add)),
      );
      await frame(tester);
      final old = share(tester).onPressed;
      cubit.edit();
      old();
      expect(received, isEmpty);
      final pending = cubit.request(lightning: false, amount: '');
      old();
      expect(received, isEmpty);
      client.reply.complete(Ok(destination));
      await pending;
      await frame(tester);
      old();
      expect(received, isEmpty);
      expect(identical(cubit.state, original), false);
      share(tester).onPressed();
      expect(received, [destination.value]);
      expect(client.calls, ['receive']);
    },
  );
  for (final sameAccount in [true, false]) {
    testWidgets(
      'old Share refuses replacement sameAccount=$sameAccount, closed owner and disposal',
      (tester) async {
        final a = ready(FakeArkClient());
        a.emit(ArkReceiveReady(payload()));
        final received = <String>[];
        await tester.pumpWidget(
          app(ArkReceiveScreen(cubit: a, onShare: received.add)),
        );
        await frame(tester);
        final old = share(tester).onPressed;
        final original = account();
        final b = ready(
          FakeArkClient(),
          owner: sameAccount
              ? original
              : ArkAccountId(
                  parent: original.parent,
                  network: original.network,
                  serverIdentity: 'different',
                ),
        );
        b.emit(ArkReceiveReady(payload()));
        await tester.pumpWidget(
          app(ArkReceiveScreen(cubit: b, onShare: received.add)),
        );
        await frame(tester);
        old();
        expect(received, isEmpty);
        expect(a.isClosed, false);
        final closed = share(tester).onPressed;
        await b.close();
        closed();
        expect(received, isEmpty);
        await tester.pumpWidget(app(const SizedBox.shrink()));
        closed();
        old();
        expect(received, isEmpty);
      },
    );
  }
  testWidgets(
    'disposed current Ready refuses Share while its owner stays open',
    (tester) async {
      final client = FakeArkClient()..destination = Ok(payload());
      final cubit = ready(client);
      await cubit.request(lightning: false, amount: '');
      final state = cubit.state;
      final received = <String>[];
      await tester.pumpWidget(
        app(ArkReceiveScreen(cubit: cubit, onShare: received.add)),
      );
      await frame(tester);
      final current = share(tester).onPressed;
      expect(cubit.isClosed, false);
      await tester.pumpWidget(app(const SizedBox.shrink()));
      expect(current, returnsNormally);
      expect(received, isEmpty);
      expect(cubit.isClosed, false);
      expect(identical(cubit.state, state), true);
      expect(client.calls, ['receive']);
    },
  );
  testWidgets(
    'valid Ready uses current handler; synchronous throwing delegate is one unchanged intent',
    (tester) async {
      final client = FakeArkClient()..destination = Ok(payload());
      final cubit = ready(client);
      await cubit.request(lightning: false, amount: '');
      final state = cubit.state;
      final oldReceived = <String>[], current = <String>[];
      await tester.pumpWidget(
        app(ArkReceiveScreen(cubit: cubit, onShare: oldReceived.add)),
      );
      await frame(tester);
      final old = share(tester).onPressed;
      await tester.pumpWidget(
        app(ArkReceiveScreen(cubit: cubit, onShare: current.add)),
      );
      await frame(tester);
      old();
      expect(oldReceived, isEmpty);
      expect(current, ['public-request']);
      final failure = StateError('scripted synchronous delegate failure');
      await tester.pumpWidget(
        app(
          ArkReceiveScreen(
            cubit: cubit,
            onShare: (value) {
              current.add(value);
              throw failure;
            },
          ),
        ),
      );
      await frame(tester);
      expect(old, throwsA(same(failure)));
      expect(current, ['public-request', 'public-request']);
      expect(identical(cubit.state, state), true);
      expect(client.calls, ['receive']);
    },
  );
}
