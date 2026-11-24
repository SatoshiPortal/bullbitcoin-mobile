import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_exchange/src/pay/presentation/pay_bloc.dart';
import 'package:bull_exchange/src/pay/ui/pay_router.dart';
import 'package:bull_exchange/src/pay/ui/screens/pay_amount_screen.dart';
import 'package:bull_exchange/src/pay/ui/screens/pay_recipient_screen.dart';
import 'package:bull_exchange/src/recipients/presentation/recipients_bloc.dart';
import 'package:bull_ui/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class _Pay extends MockBloc<PayEvent, PayState> implements PayBloc {}

class _Recipients extends MockBloc<RecipientsEvent, RecipientsState>
    implements RecipientsBloc {}

const _summary = UserSummary(
  userNumber: 1,
  groups: [],
  profile: UserProfile(firstName: 'Test', lastName: 'User'),
  email: 'test@example.test',
  balances: [],
  dca: UserDca(isActive: false),
  autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
);

final _recipient = RecipientViewModel(
  Recipient.create(
    recipientId: 'pay-recipient',
    userId: 'user',
    userNbr: 1,
    isArchived: false,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    details: InteracEmailCadDetails.create(
      email: 'pay@example.com',
      name: 'Pay',
    ),
  ),
);

void main() {
  testWidgets('a restored Pay subroute returns to the entry without extra', (
    tester,
  ) async {
    await _withPay(tester, initialLocation: '/pay/amount', (
      router,
      bloc,
      states,
    ) async {
      expect(router.routeInformationProvider.value.uri.path, '/pay');
      expect(find.byType(PayRecipientScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('Pay entry and amount share the same flow bloc', (tester) async {
    await _withPay(tester, initialLocation: '/pay', (
      router,
      bloc,
      states,
    ) async {
      final entry = tester.element(find.byType(PayRecipientScreen));
      expect(entry.read<PayBloc>(), same(bloc));

      states.add(
        PayState.amountInput(
          selectedRecipient: _recipient,
          userSummary: _summary,
        ),
      );
      await tester.pumpAndSettle();

      final amount = tester.element(find.byType(PayAmountScreen));
      expect(amount.read<PayBloc>(), same(bloc));
      expect(
        bloc.state,
        isA<PayAmountInputState>().having(
          (state) => state.selectedRecipient,
          'recipient',
          _recipient,
        ),
      );
      router.pop();
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byType(PayRecipientScreen)).read<PayBloc>(),
        same(bloc),
      );
    });
  });
}

Future<void> _withPay(
  WidgetTester tester,
  Future<void> Function(GoRouter, _Pay, StreamController<PayState>) check, {
  required String initialLocation,
}) async {
  final pay = _Pay();
  final states = StreamController<PayState>.broadcast();
  addTearDown(states.close);
  whenListen(
    pay,
    states.stream,
    initialState: const PayState.recipientSelection(userSummary: _summary),
  );
  final recipients = _Recipients();
  whenListen(
    recipients,
    const Stream<RecipientsState>.empty(),
    initialState: RecipientsState(
      recipients: const [],
      allowedRecipientFilters: RecipientFilterCriteria(),
    ),
  );
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      PayRouter.route(
        createBloc: () => pay,
        ui: (
          walletCards: (_, _) => const SizedBox.shrink(),
          addressViewer: (_, _, {style, color, textAlign}) =>
              const SizedBox.shrink(),
          openWalletHome: (_) {},
          openOrder: (_, _, {required returnToExchange}) {},
          openPayjoinTransaction: (_, _) {},
          brandAsset: 'unused',
          successAsset: 'unused',
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(extensions: testBullExtensions),
      localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
      supportedLocales: ExchangeLocalizations.supportedLocales,
      builder: (context, child) => RecipientsScope.withServices(
        services: (
          createRecipientsBloc: (_, _) => recipients,
          createVirtualIbanCubit: () => fail('Unexpected virtual IBAN'),
          createActivationCubit: (_) => fail('Unexpected activation'),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await check(router, pay, states);
}
