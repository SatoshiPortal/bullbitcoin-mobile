import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/ark_repository_impl.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/usecases/read_ark_usecase.dart';
import 'package:bull_ark/src/presentation/ark_cubit.dart';
import 'package:bull_ark/src/ui/ark_account_screen.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullBorderedTile,
        BullButton,
        BullDetailsTable,
        BullDetailsTableItem,
        SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app;
import 'ark_operations_test.dart' show account;
import 'fake_ark_client.dart';

ArkSnapshot observation({
  ArkAccountId? owner,
  bool stale = false,
  bool missing = false,
  ArkRecoveryStatus recovery = ArkRecoveryStatus.complete,
  ArkRenewalStatus renewal = ArkRenewalStatus.current,
}) => ArkSnapshot(
  account: owner ?? account(),
  revision: 2,
  observedAt: DateTime.utc(2026, 11, 16),
  stale: stale,
  spendable: missing ? null : Sats.fromInt(1234),
  pending: missing ? null : Sats.fromInt(42),
  confirmedReserve: missing ? null : Sats.fromInt(56),
  recovery: recovery,
  renewal: renewal,
);

class Client extends FakeArkClient {
  Completer<Result<ArkSnapshot, ArkWalletFailure>>? readReply;
  Completer<Result<ArkPassOutcome, ArkWalletFailure>>? passReply;
  Client() {
    pass = const Err(ArkUnavailableFailure());
  }
  @override
  Future<Result<ArkSnapshot, ArkWalletFailure>> read(ArkAccountId account) {
    final reply = readReply;
    if (reply == null) return super.read(account);
    calls.add('read');
    arguments.add(account);
    return reply.future;
  }

  @override
  Future<Result<ArkPassOutcome, ArkWalletFailure>> synchronize(
    ArkAccountId account, {
    required bool renew,
  }) {
    final reply = passReply;
    if (reply == null) return super.synchronize(account, renew: renew);
    calls.add(renew ? 'renew' : 'sync');
    arguments.add((account, renew));
    return reply.future;
  }
}

ArkCubit controller(Client client, {ArkAccountId? owner}) {
  final repository = ArkRepositoryImpl(client);
  final cubit = ArkCubit(
    ReadArkUsecase(repository),
    SynchronizeArkUsecase(repository),
    account: owner ?? account(),
  );
  addTearDown(cubit.close);
  return cubit;
}

ArkAccountScreen screen(
  ArkCubit cubit,
  List<String> calls, {
  bool enabled = true,
}) => ArkAccountScreen(
  cubit: cubit,
  enabled: enabled,
  onSend: () => calls.add('send'),
  onReceive: () => calls.add('receive'),
  onBoard: () => calls.add('board'),
  onVtxos: () => calls.add('vtxos'),
  onExits: () => calls.add('exits'),
  onInfo: () => calls.add('info'),
);
BullButton button(WidgetTester tester, String label) =>
    tester.widget<BullButton>(find.widgetWithText(BullButton, label));
List<BullButton> buttons(WidgetTester tester) =>
    tester.widgetList<BullButton>(find.byType(BullButton)).toList();
Map<String, String?> amounts(WidgetTester tester) => {
  for (final table in tester.widgetList<BullDetailsTable>(
    find.byType(BullDetailsTable),
  ))
    for (final item in table.items.whereType<BullDetailsTableItem>())
      item.label: item.displayValue,
};
const historical = 'Last observed data. Refresh before reviewing a payment.';

void main() {
  testWidgets('mount reads only and shows three exact sats balances', (
    tester,
  ) async {
    final client = Client()..snapshot = Ok(observation());
    final cubit = controller(client);
    final calls = <String>[];
    await tester.pumpWidget(app(screen(cubit, calls)));
    await tester.pump();
    expect(client.calls, ['read']);
    expect(calls, isEmpty);
    expect(amounts(tester), {
      'Spendable (sats)': '1234',
      'Pending (sats)': '42',
      'On-chain fee reserve (sats)': '56',
    });
  });
  testWidgets(
    'explicit refresh deduplicates while actual synchronization remains pending',
    (tester) async {
      final reply = Completer<Result<ArkPassOutcome, ArkWalletFailure>>();
      final client = Client()
        ..snapshot = Ok(observation())
        ..passReply = reply;
      final cubit = controller(client);
      await tester.pumpWidget(app(screen(cubit, [])));
      await tester.pump();
      final refresh = button(tester, 'Refresh').onPressed;
      refresh();
      refresh();
      await tester.pump();
      expect(client.calls, ['read', 'sync']);
      expect(client.arguments.last, (account(), false));
      reply.complete(Ok(ArkPassOutcome(snapshot: observation())));
      await tester.pump();
    },
  );
  testWidgets('loading and null observations are not zero balances', (
    tester,
  ) async {
    final reply = Completer<Result<ArkSnapshot, ArkWalletFailure>>();
    final client = Client()..readReply = reply;
    final cubit = controller(client);
    await tester.pumpWidget(app(screen(cubit, [])));
    expect(find.text('Loading Ark…'), findsOneWidget);
    expect(amounts(tester), isEmpty);
    reply.complete(Ok(observation(missing: true)));
    await tester.pump();
    expect(amounts(tester).values, everyElement('Unavailable'));
    expect(find.text('0'), findsNothing);
  });
  testWidgets('failed refresh marks retained stale=false data historical', (
    tester,
  ) async {
    final snapshot = observation();
    final client = Client()
      ..snapshot = Ok(snapshot)
      ..pass = const Err(ArkUnavailableFailure());
    final cubit = controller(client);
    await tester.pumpWidget(app(screen(cubit, [])));
    await tester.pump();
    expect(find.text(historical), findsNothing);
    await cubit.refresh();
    await tester.pump();
    expect((cubit.state as ArkViewFailed).lastObserved?.stale, false);
    expect(find.text(historical), findsOneWidget);
    expect(amounts(tester)['Spendable (sats)'], '1234');
  });
  testWidgets('stale observed data is qualified separately from failure', (
    tester,
  ) async {
    final cubit = controller(Client()..snapshot = Ok(observation(stale: true)));
    await tester.pumpWidget(app(screen(cubit, [])));
    await tester.pump();
    expect(find.text(historical), findsOneWidget);
    expect(cubit.state, isA<ArkObserved>());
  });
  for (final failed in [false, true]) {
    testWidgets('foreign snapshot is not displayed in failed=$failed state', (
      tester,
    ) async {
      final cubit = controller(Client()..snapshot = Ok(observation()));
      await tester.pumpWidget(app(screen(cubit, [])));
      await tester.pump();
      final original = account();
      final foreign = observation(
        owner: ArkAccountId(
          parent: original.parent,
          network: original.network,
          serverIdentity: 'other-server',
        ),
        renewal: ArkRenewalStatus.due,
      );
      // Bloc's public @visibleForTesting emit isolates the widget's defensive boundary.
      cubit.emit(
        failed
            ? ArkViewFailed(
                const ArkServiceUnavailableFailure(),
                lastObserved: foreign,
              )
            : ArkObserved(foreign),
      );
      await tester.pump();
      expect(amounts(tester), isEmpty);
      expect(find.text('1234'), findsNothing);
      expect(find.byType(BullBorderedTile), findsNothing);
      expect(find.text('Unavailable'), findsWidgets);
    });
  }
  for (final sameAccount in [false, true]) {
    testWidgets(
      'old callbacks refuse replaced Cubit sameAccount=$sameAccount',
      (tester) async {
        final a = controller(
          Client()..snapshot = Ok(observation(renewal: ArkRenewalStatus.due)),
        );
        final oldCalls = <String>[];
        final newCalls = <String>[];
        await tester.pumpWidget(app(screen(a, oldCalls)));
        await tester.pump();
        final old = buttons(tester).map((b) => b.onPressed).toList();
        final attention = tester
            .widget<BullBorderedTile>(find.byType(BullBorderedTile))
            .onTap;
        final original = account();
        final owner = sameAccount
            ? original
            : ArkAccountId(
                parent: original.parent,
                network: original.network,
                serverIdentity: 'replacement-server',
              );
        final client = Client()..snapshot = Ok(observation(owner: owner));
        final b = controller(client, owner: owner);
        await tester.pumpWidget(app(screen(b, newCalls)));
        await tester.pump();
        for (final callback in old) {
          callback();
        }
        attention?.call();
        await tester.pump();
        expect(oldCalls, isEmpty);
        expect(newCalls, isEmpty);
        expect(client.calls, ['read']);
        expect(a.isClosed, false);
        expect(b.isClosed, false);
      },
    );
  }
  testWidgets('same Cubit callbacks use current handlers', (tester) async {
    final cubit = controller(Client()..snapshot = Ok(observation()));
    final oldCalls = <String>[];
    final newCalls = <String>[];
    await tester.pumpWidget(app(screen(cubit, oldCalls)));
    await tester.pump();
    final send = button(tester, 'Send').onPressed;
    await tester.pumpWidget(app(screen(cubit, newCalls)));
    send();
    expect(oldCalls, isEmpty);
    expect(newCalls, ['send']);
  });
  for (final recovery in [
    ArkRecoveryStatus.unknown,
    ArkRecoveryStatus.incomplete,
  ]) {
    testWidgets(
      'funded-off recovery $recovery preserves protective navigation and guards stale payment callbacks',
      (tester) async {
        final cubit = controller(
          Client()..snapshot = Ok(observation(recovery: recovery)),
        );
        final calls = <String>[];
        await tester.pumpWidget(app(screen(cubit, calls)));
        await tester.pump();
        final oldPayments = [
          'Send',
          'Receive',
          'Add funds',
        ].map((label) => button(tester, label).onPressed).toList();
        await tester.pumpWidget(app(screen(cubit, calls, enabled: false)));
        for (final callback in oldPayments) {
          callback();
        }
        for (final label in ['Send', 'Receive', 'Add funds']) {
          expect(button(tester, label).disabled, true);
          button(tester, label).onPressed();
        }
        expect(calls, isEmpty);
        for (final label in ['VTXOs', 'Emergency exit', 'Server information']) {
          button(tester, label).onPressed();
        }
        expect(calls, ['vtxos', 'exits', 'info']);
      },
    );
  }
  testWidgets(
    'late old read cannot update a rebound screen and disposal closes no injected Cubit',
    (tester) async {
      final reply = Completer<Result<ArkSnapshot, ArkWalletFailure>>();
      final oldClient = Client()..readReply = reply;
      final old = controller(oldClient);
      final current = controller(
        Client()..snapshot = Ok(observation(missing: true)),
      );
      final calls = <String>[];
      await tester.pumpWidget(app(screen(old, calls)));
      await tester.pumpWidget(app(screen(current, calls)));
      await tester.pump();
      reply.complete(Ok(observation()));
      await tester.pump();
      expect(find.text('1234'), findsNothing);
      final callbacks = buttons(tester).map((b) => b.onPressed).toList();
      await tester.pumpWidget(app(const SizedBox.shrink()));
      for (final callback in callbacks) {
        callback();
      }
      await tester.pump();
      expect(calls, isEmpty);
      expect(old.isClosed, false);
      expect(current.isClosed, false);
    },
  );
}
