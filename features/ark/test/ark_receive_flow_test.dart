import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/ark_repository_impl.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/usecases/create_ark_receive_usecase.dart';
import 'package:bull_ark/src/domain/usecases/request_ark_receive_usecase.dart';
import 'package:bull_ark/src/presentation/ark_receive_cubit.dart';
import 'package:bull_ark/src/ui/ark_receive_screen.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullDetailsTable, BullDetailsTableItem;
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

import 'ark_operations_test.dart' show account, Preferences;
import 'fake_ark_client.dart';

class DelayedReceive extends FakeArkClient {
  final reply = Completer<Result<ArkReceiveDestination, ArkWalletFailure>>();
  @override
  Future<Result<ArkReceiveDestination, ArkWalletFailure>> receive(
    ArkAccountId account,
    ArkReceiveRequest request,
  ) {
    calls.add('receive');
    arguments.add((account, request));
    return reply.future;
  }
}

ArkReceiveDestination destination() => ArkReceiveDestination(
  kind: ArkDestinationKind.bolt11,
  value: 'lnbc1public-test-invoice',
  fee: Sats.fromInt(100),
  net: Sats.fromInt(900),
  expiresAt: DateTime.utc(2027),
);

ArkReceiveCubit controller(
  FakeArkClient client, {
  Preferences? preferences,
  ArkAccountId? id,
}) => ArkReceiveCubit(
  RequestArkReceiveUsecase(
    CreateArkReceiveUsecase(
      ArkRepositoryImpl(client),
      preferences ?? Preferences(),
    ),
  ),
  account: id ?? account(),
);

Widget app(Widget child) => MaterialApp(
  theme: ThemeData(extensions: testBullExtensions),
  home: child,
);

void main() {
  testWidgets(
    'replacement account drops form state and ignores the old pending invoice',
    (tester) async {
      final oldClient = DelayedReceive();
      final old = controller(oldClient);
      final newAccount = ArkAccountId(
        parent: Fingerprint('22334455'),
        network: account().network,
        serverIdentity: account().serverIdentity,
      );
      final newClient = FakeArkClient()
        ..destination = Ok(
          ArkReceiveDestination(
            kind: ArkDestinationKind.ark,
            value: 'new-public-ark-address',
          ),
        );
      final replacement = controller(newClient, id: newAccount);
      addTearDown(old.close);
      addTearDown(replacement.close);
      await tester.pumpWidget(app(ArkReceiveScreen(cubit: old)));
      await tester.tap(find.text('Lightning invoice'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '1000');
      await tester.tap(find.text('Create request'));
      await tester.pump();
      await tester.pumpWidget(app(ArkReceiveScreen(cubit: replacement)));
      await tester.pump();
      final amountFieldsAfterReplacement = find
          .byType(TextField)
          .evaluate()
          .length;
      await tester.tap(find.text('Create request'));
      await tester.pumpAndSettle();
      oldClient.reply.complete(Ok(destination()));
      await tester.pumpAndSettle();
      expect(amountFieldsAfterReplacement, 0);
      expect(find.text('new-public-ark-address'), findsOneWidget);
      expect(find.text('lnbc1public-test-invoice'), findsNothing);
      final command = newClient.arguments
          .whereType<(ArkAccountId, ArkReceiveRequest)>()
          .single;
      expect(command.$1, newAccount);
      expect(command.$2, isA<ArkAddressReceiveRequest>());
      expect(oldClient.calls, ['receive']);
      expect(newClient.calls, ['receive']);
    },
  );

  testWidgets(
    'unavailable backend renders a localized failure without invented receive data',
    (tester) async {
      final client = FakeArkClient()
        ..destination = const Err(ArkUnavailableFailure());
      final cubit = controller(client);
      addTearDown(cubit.close);
      await tester.pumpWidget(app(ArkReceiveScreen(cubit: cubit)));
      await tester.tap(find.text('Create request'));
      await tester.pumpAndSettle();
      expect(find.text('Ark is unavailable. Try again.'), findsOneWidget);
      expect(find.byType(BullDetailsTable), findsNothing);
      expect(client.calls, ['receive']);
    },
  );

  test(
    'editing cannot admit a second receive before the first future settles',
    () async {
      final client = DelayedReceive();
      final cubit = controller(client);
      addTearDown(cubit.close);
      final pending = cubit.request(lightning: true, amount: '1000');
      cubit.edit();
      final second = cubit.request(lightning: true, amount: '2000');
      client.reply.complete(Ok(destination()));
      await Future.wait([pending, second]);
      expect(client.calls, ['receive']);
      expect(cubit.state, isA<ArkReceiveEditing>());
    },
  );

  test(
    'edited pending request stays busy and never publishes its old destination',
    () async {
      final client = DelayedReceive();
      final cubit = controller(client);
      addTearDown(cubit.close);
      final pending = cubit.request(lightning: true, amount: '1000');
      cubit.edit();
      final whilePending = cubit.state;
      client.reply.complete(Ok(destination()));
      await pending;
      expect(whilePending, isA<ArkReceiveLoading>());
      expect(cubit.state, isA<ArkReceiveEditing>());
    },
  );

  test(
    'amount and account are captured without a quote or automatic spend',
    () async {
      final client = FakeArkClient()..destination = Ok(destination());
      final cubit = controller(client);
      addTearDown(cubit.close);
      await cubit.request(lightning: true, amount: '1000');
      expect(client.calls, ['receive']);
      final command = client.arguments
          .whereType<(ArkAccountId, ArkReceiveRequest)>()
          .single;
      expect(command.$1, account());
      expect(
        command.$2,
        isA<ArkBolt11ReceiveRequest>().having(
          (r) => r.amount.value,
          'invoice amount',
          BigInt.from(1000),
        ),
      );
      expect(cubit.state, isA<ArkReceiveReady>());
    },
  );

  test(
    'off and invalid amount remain typed refusals with no native call',
    () async {
      final client = FakeArkClient();
      final preferences = Preferences()..enabled = false;
      final cubit = controller(client, preferences: preferences);
      addTearDown(cubit.close);
      await cubit.request(lightning: false, amount: '');
      expect(
        cubit.state,
        isA<ArkReceiveEditing>().having(
          (s) => s.failure,
          'off',
          isA<ArkDisabledFailure>(),
        ),
      );
      preferences.enabled = true;
      await cubit.request(lightning: true, amount: '1.5');
      expect(
        cubit.state,
        isA<ArkReceiveEditing>().having(
          (s) => s.failure,
          'invalid amount',
          isA<ArkInvalidRequestFailure>(),
        ),
      );
      expect(client.calls, isEmpty);
    },
  );

  testWidgets(
    'saved receive fee and net render exact amounts with explicit sats labels',
    (tester) async {
      final client = FakeArkClient()..destination = Ok(destination());
      final cubit = controller(client);
      addTearDown(cubit.close);
      await tester.pumpWidget(app(ArkReceiveScreen(cubit: cubit)));
      await tester.tap(find.text('Lightning invoice'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '1000');
      await tester.tap(find.text('Create request'));
      await tester.pumpAndSettle();
      expect(find.text('lnbc1public-test-invoice'), findsOneWidget);
      expect(find.text('Fee (sats)'), findsOneWidget);
      expect(find.text('Net amount (sats)'), findsOneWidget);
      final rows = tester
          .widget<BullDetailsTable>(find.byType(BullDetailsTable))
          .items
          .whereType<BullDetailsTableItem>();
      expect(
        rows.singleWhere((r) => r.label == 'Fee (sats)').displayValue,
        '100',
      );
      expect(
        rows.singleWhere((r) => r.label == 'Net amount (sats)').displayValue,
        '900',
      );
      expect(client.calls, ['receive']);
    },
  );
}
