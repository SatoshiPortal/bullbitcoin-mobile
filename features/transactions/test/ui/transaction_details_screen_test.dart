import 'dart:async';
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
    TransactionDetailsState? detailsState,
    bool? animationsEnabled = true,
    String query = '?returnHome=true',
    TransactionStatusState? statusState,
    Object? extra,
    SettlementPoll? pollOverride,
    Size size = const Size(800, 1600),
    double textScale = 1,
    Locale? locale,
  }) async {
    details = _FakeDetailsCubit(
      detailsState ??
          TransactionDetailsState(transaction: transaction ?? pendingSend()),
    );
    status = _FakeStatusCubit(
      statusState ??
          TransactionStatusState(animationsEnabled: animationsEnabled),
    )..observed.clear();
    polls = [];
    _MockActions.homes = 0;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/transaction/tx$query',
      initialExtra: extra,
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, _) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/other',
          builder: (context, _) => const Scaffold(body: Text('other')),
        ),
        GoRoute(
          name: 'transactionDetails',
          path: '/transaction/:txId',
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider<TransactionDetailsCubit>.value(value: details),
              BlocProvider<TransactionStatusCubit>.value(value: status),
            ],
            child: TransactionDetailsScreen(
              actions: _MockActions.actions,
              pollSettlement:
                  pollOverride ??
                  (walletId, {required isActive}) async {
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
        locale: locale,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        ),
        theme: AppTheme.themeData(AppThemeType.dark),
        localizationsDelegates: const [
          ...TransactionsLocalizations.localizationsDelegates,
          bullUiLocalizationsDelegate,
          ...GlobalMaterialLocalizations.delegates,
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

  for (final (language, label) in [
    ('en', 'Status'),
    ('fr', 'Statut'),
    ('es', 'Estado'),
  ]) {
    testWidgets('payment view uses the status label in $language', (
      tester,
    ) async {
      await pump(tester, locale: Locale(language));
      expect(button(label), findsOneWidget);
    });
  }

  testWidgets('broadcast keeps its scene and switch across observation', (
    tester,
  ) async {
    await pump(
      tester,
      query: '?walletId=w1',
      extra: (txId: 'tx', walletId: 'w1', isLiquid: false),
      detailsState: const TransactionDetailsState(
        failure: TransactionNotFoundFailure(),
      ),
    );
    final transition = find.byType(BullPaymentTransition);
    final switcher = find.byType(BullPaymentViewSwitch);
    expect(find.byType(BullPaymentViews), findsOneWidget);
    expect(switcher, findsOneWidget);
    final oldState = tester.state(transition);
    final sceneRect = tester.getRect(transition);
    final switchRect = tester.getRect(switcher);
    details.emit(TransactionDetailsState(transaction: pendingSend()));
    await tester.pump();
    expect(tester.state(transition), same(oldState));
    expect(tester.getRect(transition), sceneRect);
    expect(tester.getRect(switcher), switchRect);
  });

  for (final animated in [true, false]) {
    testWidgets('broadcast intent prevents a preference flash: $animated', (
      tester,
    ) async {
      await pump(
        tester,
        query: animated ? '?walletId=w1' : '?walletId=w1&view=details',
        extra: (txId: 'tx', walletId: 'w1', isLiquid: false),
        animationsEnabled: null,
        detailsState: const TransactionDetailsState(
          failure: TransactionNotFoundFailure(),
        ),
      );
      expect(
        find.byType(BullPaymentTransition),
        animated ? findsOneWidget : findsNothing,
      );
      expect(find.byType(AppBar), animated ? findsNothing : findsOneWidget);
      expect(find.text('Waiting for the transaction'), findsOneWidget);
      status.emit(TransactionStatusState(animationsEnabled: animated));
      await tester.pump();
      expect(
        find.byType(BullPaymentTransition),
        animated ? findsOneWidget : findsNothing,
      );
    });
  }

  testWidgets('waiting selector fits a narrow screen with enlarged text', (
    tester,
  ) async {
    await pump(
      tester,
      size: const Size(320, 700),
      textScale: 2,
      query: '?walletId=w1',
      extra: (txId: 'tx', walletId: 'w1', isLiquid: false),
      detailsState: const TransactionDetailsState(
        failure: TransactionNotFoundFailure(),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(BullToolButton, 'Status'), findsOneWidget);
    expect(find.widgetWithText(BullToolButton, 'Details'), findsOneWidget);
    await tester.tap(find.widgetWithText(BullToolButton, 'Details'));
    await tester.pump();
    expect(find.text('Waiting for the transaction'), findsOneWidget);
  });

  testWidgets('a proven broadcast waits and syncs its wallet', (tester) async {
    await pump(
      tester,
      query: '?walletId=w1',
      extra: (txId: 'tx', walletId: 'w1', isLiquid: false),
      detailsState: const TransactionDetailsState(
        failure: TransactionNotFoundFailure(),
      ),
    );
    expect(polls, ['w1']);
    expect(find.text('Waiting for the transaction'), findsOneWidget);
    expect(find.text('Could not load transaction'), findsNothing);
  });

  testWidgets('a missing ordinary transaction remains an error', (
    tester,
  ) async {
    await pump(
      tester,
      query: '?walletId=w1',
      detailsState: const TransactionDetailsState(
        failure: TransactionNotFoundFailure(),
      ),
    );
    expect(polls, isEmpty);
    expect(find.text('Waiting for the transaction'), findsNothing);
  });

  testWidgets('broadcast context cannot apply to a different wallet', (
    tester,
  ) async {
    await pump(
      tester,
      query: '?walletId=w1',
      extra: (txId: 'tx', walletId: 'other', isLiquid: false),
      detailsState: const TransactionDetailsState(
        failure: TransactionNotFoundFailure(),
      ),
    );
    expect(polls, isEmpty);
    expect(find.text('Waiting for the transaction'), findsNothing);
  });

  testWidgets('broadcast lookup is bounded and Retry starts a new attempt', (
    tester,
  ) async {
    await pump(
      tester,
      query: '?walletId=w1',
      extra: (txId: 'tx', walletId: 'w1', isLiquid: true),
      detailsState: const TransactionDetailsState(
        failure: TransactionNotFoundFailure(),
      ),
    );
    await tester.pump(const Duration(seconds: 20));
    await tester.pump(const Duration(seconds: 20));
    await tester.pump(const Duration(minutes: 2));
    expect(polls, ['w1', 'w1', 'w1']);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(polls, hasLength(4));
  });

  testWidgets('Details offers Retry when the indexing wait expires', (
    tester,
  ) async {
    await pump(
      tester,
      query: '?walletId=w1',
      extra: (txId: 'tx', walletId: 'w1', isLiquid: true),
      detailsState: const TransactionDetailsState(
        failure: TransactionNotFoundFailure(),
      ),
    );
    await tester.tap(button('Details'));
    await tester.pump();
    expect(find.text('Waiting for the transaction'), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(polls, hasLength(4));
  });

  testWidgets('broadcast lookup pauses while the app is not resumed', (
    tester,
  ) async {
    await pump(
      tester,
      query: '?walletId=w1',
      extra: (txId: 'tx', walletId: 'w1', isLiquid: true),
      detailsState: const TransactionDetailsState(
        failure: TransactionNotFoundFailure(),
      ),
    );
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    await tester.pump(const Duration(minutes: 2));
    expect(polls, hasLength(1));
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(polls, hasLength(2));
  });

  testWidgets('broadcast lookup pauses while another route is visible', (
    tester,
  ) async {
    await pump(
      tester,
      query: '?walletId=w1',
      extra: (txId: 'tx', walletId: 'w1', isLiquid: true),
      detailsState: const TransactionDetailsState(
        failure: TransactionNotFoundFailure(),
      ),
    );
    final router = GoRouter.of(
      tester.element(find.byType(TransactionDetailsScreen)),
    );
    unawaited(router.push('/other'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 2));
    expect(polls, hasLength(1));
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(polls, hasLength(2));
  });

  testWidgets('a stalled sync is bounded and loses its admission', (
    tester,
  ) async {
    final gate = Completer<void>();
    late bool Function() active;
    await pump(
      tester,
      query: '?walletId=w1',
      extra: (txId: 'tx', walletId: 'w1', isLiquid: true),
      detailsState: const TransactionDetailsState(
        failure: TransactionNotFoundFailure(),
      ),
      pollOverride: (_, {required isActive}) {
        active = isActive;
        return gate.future;
      },
    );
    expect(active(), isTrue);
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(active(), isFalse);
    expect(details.refreshes, 1);
    gate.complete();
  });

  for (final animations in [true, false]) {
    testWidgets('observation opens the configured view: $animations', (
      tester,
    ) async {
      await pump(
        tester,
        query: '?walletId=w1',
        extra: (txId: 'tx', walletId: 'w1', isLiquid: false),
        animationsEnabled: animations,
        detailsState: const TransactionDetailsState(
          failure: TransactionNotFoundFailure(),
        ),
      );
      details.emit(TransactionDetailsState(transaction: pendingSend()));
      await tester.pump();
      await tester.pump();
      expect(
        status.observed,
        contains(
          const TransactionSettlementTarget(walletId: 'wallet', txId: 'tx'),
        ),
      );
      expect(
        find.byType(BullPaymentTransition),
        animations ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(BullTransactionDetailsPage),
        animations ? findsNothing : findsOneWidget,
      );
    });
  }

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

    testWidgets('the switch sits at the same place on both views', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byType(BullPaymentTransition), findsOneWidget);
      final onStatus = tester.getRect(find.byType(BullPaymentViewSwitch));

      await tester.tap(button('Details'));
      await tester.pump();
      expect(find.byType(BullTransactionDetailsPage), findsOneWidget);
      final onDetails = tester.getRect(find.byType(BullPaymentViewSwitch));
      expect(onDetails, onStatus);

      await tester.tap(button('Status'));
      await tester.pump();
      expect(tester.getRect(find.byType(BullPaymentViewSwitch)), onStatus);
      // Centred on the screen.
      expect(onStatus.center.dx, 400);
    });

    testWidgets('animations off or unknown shows no switch', (tester) async {
      await pump(tester, animationsEnabled: false);
      expect(find.byType(BullTransactionDetailsPage), findsOneWidget);
      expect(find.byType(BullPaymentViewSwitch), findsNothing);
      expect(find.byType(BullToolButton), findsNothing);

      await pump(tester, animationsEnabled: null);
      expect(find.byType(BullPaymentViewSwitch), findsNothing);
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
      await pump(tester, query: '?view=details');
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
