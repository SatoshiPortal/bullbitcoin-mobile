import 'dart:ui' show Tristate;

import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:swaps/swaps.dart';
import 'package:transactions/generated/l10n/transactions_localizations.dart';
import 'package:transactions/setup.dart' show TransactionUiActions;
import 'package:transactions/testing.dart';

import '../presentation/animation_fixtures.dart';

class _FakeDetailsCubit extends Cubit<TransactionDetailsState>
    implements TransactionDetailsCubit {
  _FakeDetailsCubit(super.initialState);

  int refreshes = 0;

  @override
  Future<void> refresh() async => refreshes++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStatusCubit extends Cubit<TransactionStatusState>
    implements TransactionStatusCubit {
  _FakeStatusCubit(super.initialState);

  final observed = <TransactionSettlementTarget?>[];

  @override
  void observeSettlement(TransactionSettlementTarget? target) =>
      observed.add(target);

  @override
  Future<void> loadPreference() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockActions {
  static int homes = 0;

  static final actions = TransactionUiActions(
    openExchange: (_) {},
    openWalletHome: (context) {
      homes++;
      context.go('/home');
    },
    refreshWallets: (_) async {},
    accelerateOrder: (_, _) => const SizedBox.shrink(),
    showReceipt: (_, _) {},
    accelerateWalletTransaction: (_, _) {},
    orderSwapUnderReview: (_) => const SizedBox.shrink(),
    addressViewer: (address, style) => Text(address, style: style),
  );
}

void main() {
  late _FakeDetailsCubit details;
  late _FakeStatusCubit status;
  late List<String> polls;

  Transaction pendingSend() => Transaction(walletTransaction: walletTx('tx'));

  Transaction refundableSwap() => Transaction(
    swap: Swap.chain(
      id: 'chain',
      keyIndex: 0,
      type: SwapType.bitcoinToLiquid,
      status: SwapStatus.refundable,
      environment: SwapEnvironment.testnet,
      creationTime: DateTime.utc(2026),
      sendWalletId: 'source',
      paymentAddress: 'address',
      paymentAmount: 1000,
      sendTxid: 'lockup',
    ),
  );

  Future<void> pump(
    WidgetTester tester, {
    Transaction? transaction,
    bool? animationsEnabled = true,
    String query = '?returnHome=true',
    TransactionStatusState? statusState,
  }) async {
    details = _FakeDetailsCubit(
      TransactionDetailsState(transaction: transaction ?? pendingSend()),
    );
    status = _FakeStatusCubit(
      statusState ??
          TransactionStatusState(animationsEnabled: animationsEnabled),
    )..observed.clear();
    polls = [];
    _MockActions.homes = 0;
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/transaction/tx$query',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, _) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/transaction/:txId',
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider<TransactionDetailsCubit>.value(value: details),
              BlocProvider<TransactionStatusCubit>.value(value: status),
            ],
            child: TransactionDetailsScreen(
              actions: _MockActions.actions,
              pollSettlement: (walletId, {required isActive}) async {
                polls.add(walletId);
              },
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(details.close);
    addTearDown(status.close);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.themeData(AppThemeType.dark),
        localizationsDelegates: const [
          ...TransactionsLocalizations.localizationsDelegates,
          bullUiLocalizationsDelegate,
        ],
        supportedLocales: TransactionsLocalizations.supportedLocales,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Finder button(String label) => find.widgetWithText(BullToolButton, label);

  bool selected(WidgetTester tester, String label) =>
      tester.getSemantics(button(label)).flagsCollection.isSelected ==
      Tristate.isTrue;

  group('initial view', () {
    testWidgets('opens on the payment status by default', (tester) async {
      await pump(tester);
      expect(find.byType(BullPaymentTransition), findsOneWidget);
      expect(find.byType(BullTransactionDetailsPage), findsNothing);
    });

    testWidgets('view=details opens on the details', (tester) async {
      await pump(tester, query: '?view=details');
      expect(find.byType(BullPaymentTransition), findsNothing);
      expect(find.byType(BullTransactionDetailsPage), findsOneWidget);
    });

    testWidgets('animations off opens on the details', (tester) async {
      await pump(tester, animationsEnabled: false);
      expect(find.byType(BullPaymentTransition), findsNothing);
      expect(find.byType(BullTransactionDetailsPage), findsOneWidget);
    });

    testWidgets('a pending recovery action opens on the details', (
      tester,
    ) async {
      await pump(tester, transaction: refundableSwap());
      expect(find.byType(BullPaymentTransition), findsNothing);
      expect(find.byType(BullTransactionDetailsPage), findsOneWidget);
    });

    testWidgets('waits for the preference before choosing', (tester) async {
      await pump(tester, animationsEnabled: null);
      expect(find.byType(BullPaymentTransition), findsNothing);
      status.emit(const TransactionStatusState(animationsEnabled: true));
      await tester.pump();
      await tester.pump();
      expect(find.byType(BullPaymentTransition), findsOneWidget);
    });

    testWidgets('a transaction without an animation shows details alone', (
      tester,
    ) async {
      await pump(tester, transaction: Transaction(order: sellOrder()));
      expect(find.byType(BullTransactionDetailsPage), findsOneWidget);
      expect(find.byType(BullToolButton), findsNothing);
    });
  });

  group('system back', () {
    testWidgets('closes exactly once on the status view', (tester) async {
      await pump(tester);
      expect(find.byType(BullPaymentTransition), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(_MockActions.homes, 1);
    });

    testWidgets('closes exactly once on the details view of a built status', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(button('Details'));
      await tester.pump();
      expect(find.byType(BullTransactionDetailsPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(_MockActions.homes, 1);
    });

    testWidgets('closes exactly once on a details-only screen', (tester) async {
      await pump(tester, query: '?returnHome=true&view=details');
      expect(find.byType(BullPaymentTransition), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(_MockActions.homes, 1);
    });
  });

  group('switching', () {
    testWidgets('the buttons switch between status and details', (
      tester,
    ) async {
      await pump(tester);
      expect(button('Status'), findsOneWidget);
      expect(button('Details'), findsOneWidget);
      expect(find.text('Transaction details'), findsNothing);

      await tester.tap(button('Details'));
      await tester.pump();
      expect(find.byType(BullTransactionDetailsPage), findsOneWidget);
      expect(find.byType(BullPaymentTransition), findsNothing);
      expect(button('Status'), findsOneWidget);

      await tester.tap(button('Status'));
      await tester.pump();
      expect(find.byType(BullPaymentTransition), findsOneWidget);
      expect(find.byType(BullTransactionDetailsPage), findsNothing);
    });

    testWidgets('the switch is reachable and activated from the keyboard', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byType(BullPaymentTransition), findsOneWidget);
      var guard = 0;
      bool onDetails() =>
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<BullToolButton>()
              ?.label ==
          'Details';
      while (!onDetails() && guard++ < 20) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(guard, lessThan(20));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.byType(BullTransactionDetailsPage), findsOneWidget);
      expect(find.byType(BullPaymentTransition), findsNothing);
    });

    testWidgets('the shown view is primary and selected', (tester) async {
      await pump(tester);
      expect(tester.widget<BullToolButton>(button('Status')).primary, isTrue);
      expect(tester.widget<BullToolButton>(button('Details')).primary, isFalse);
      expect(selected(tester, 'Status'), isTrue);
      expect(selected(tester, 'Details'), isFalse);

      await tester.tap(button('Details'));
      await tester.pump();
      expect(selected(tester, 'Status'), isFalse);
      expect(selected(tester, 'Details'), isTrue);
      expect(tester.widget<BullToolButton>(button('Details')).primary, isTrue);
    });

    testWidgets('the buttons are semantic buttons', (tester) async {
      await pump(tester);
      expect(
        tester.getSemantics(button('Details')),
        matchesSemantics(
          label: 'Details',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasSelectedState: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
    });

    testWidgets('the hidden status view does not tick', (tester) async {
      await pump(tester, animationsEnabled: false);
      await tester.tap(button('Status'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.tap(button('Details'));
      await tester.pump();
      // Past the button's own ink splash, nothing is left ticking.
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('a status view never shown is never built', (tester) async {
      await pump(tester, animationsEnabled: false);
      expect(
        find.byType(BullPaymentTransition, skipOffstage: false),
        findsNothing,
      );
    });
  });

  group('details view', () {
    testWidgets('pull to refresh stays on the details', (tester) async {
      await pump(tester, query: '?view=details');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 420));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(details.refreshes, 1);
    });

    testWidgets('carries the same Status | Details pair', (tester) async {
      await pump(tester, query: '?view=details');
      await tester.scrollUntilVisible(
        button('Status'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(button('Status'), findsOneWidget);
      expect(selected(tester, 'Details'), isTrue);
    });
  });

  group('close', () {
    testWidgets('back on the status view keeps the returnHome semantics', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('system back on the status view goes home', (tester) async {
      await pump(tester);
      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handled, isTrue);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('close on the details view keeps the returnHome semantics', (
      tester,
    ) async {
      await pump(tester, query: '?view=details&returnHome=true');
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });
  });

  group('settlement', () {
    const target = TransactionSettlementTarget(walletId: 'wallet', txId: 'tx');

    testWidgets('observes the settlement of the displayed transaction', (
      tester,
    ) async {
      await pump(tester);
      await tester.pump();
      expect(status.observed, [target]);
      details.emit(
        TransactionDetailsState(
          transaction: Transaction(walletTransaction: walletTx('other')),
        ),
      );
      await tester.pump();
      expect(
        status.observed.last,
        const TransactionSettlementTarget(walletId: 'wallet', txId: 'other'),
      );
    });

    testWidgets('polls the wallet while the status view waits', (tester) async {
      await pump(
        tester,
        statusState: const TransactionStatusState(
          animationsEnabled: true,
          settlementTarget: target,
        ),
      );
      expect(polls, ['wallet']);
    });

    testWidgets('does not poll once the settlement is confirmed', (
      tester,
    ) async {
      await pump(
        tester,
        statusState: TransactionStatusState(
          animationsEnabled: true,
          settlementTarget: target,
          settlement: walletTx('tx', confirmed: true),
        ),
      );
      expect(polls, isEmpty);
    });

    testWidgets('does not poll while the details are shown', (tester) async {
      await pump(
        tester,
        query: '?view=details',
        statusState: const TransactionStatusState(
          animationsEnabled: true,
          settlementTarget: target,
        ),
      );
      expect(polls, isEmpty);
      await tester.tap(button('Status'));
      await tester.pump();
      expect(polls, ['wallet']);
    });
  });
}
