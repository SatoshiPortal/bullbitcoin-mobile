import 'dart:async';

import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:receive/setup.dart' show ReceiveLocalizations;
import 'package:receive/src/presentation/bloc/receive_bloc.dart';
import 'package:receive/src/ui/screens/receive_payjoin_in_progress_screen.dart';
import 'package:transactions/transactions.dart';
import 'package:transactions/setup.dart' show TransactionsLocalizations;
import 'package:transactions/routes.dart';

class _Bloc extends Fake implements ReceiveBloc {
  _Bloc(this._state);
  ReceiveState _state;
  final _events = StreamController<ReceiveState>.broadcast();
  @override
  ReceiveState get state => _state;
  @override
  Stream<ReceiveState> get stream => _events.stream;
  @override
  bool get isClosed => _events.isClosed;
  void update(ReceiveState state) {
    _state = state;
    _events.add(state);
  }

  @override
  Future<void> close() => _events.close();
}

void main() {
  testWidgets('switching views keeps the same transition mounted', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 457);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final bloc = _Bloc(
      ReceiveState(
        type: ReceiveType.bitcoin,
        payjoin: PayjoinReceiverSession(
          status: PayjoinStatus.completed,
          id: 'session',
          network: BitcoinNetwork.regtest,
          walletId: 'wallet',
          createdAt: now,
          expiresAt: now.add(const Duration(hours: 1)),
          payjoinUri: 'https://example.com',
          transactionId: 'target',
          hasOriginalTransaction: true,
          hasProposal: true,
        ),
        showPaymentAnimations: true,
      ),
    );
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.dark),
        localizationsDelegates: const [
          bullUiLocalizationsDelegate,
          ReceiveLocalizations.delegate,
          TransactionsLocalizations.delegate,
        ],
        supportedLocales: ReceiveLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child ?? const SizedBox(),
        ),
        home: BlocProvider<ReceiveBloc>.value(
          value: bloc,
          child: ReceivePayjoinInProgressScreen(openHome: (_) {}),
        ),
      ),
    );
    final allTransitions = find.byType(
      BullPaymentTransition,
      skipOffstage: false,
    );
    final instance = tester.state(allTransitions);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    final scene = tester.getRect(find.byType(BullPaymentTransition));
    final selector = tester.getRect(find.byType(BullPaymentViewSwitch));
    expect(scene.left, 0);
    expect(scene.top, 0);
    expect(scene.width, 320);
    expect(scene.height, greaterThan(320));
    await tester.pump(const Duration(seconds: 2));
    tester
        .widget<BullPaymentViewSwitch>(find.byType(BullPaymentViewSwitch))
        .onDetails();
    await tester.pump();
    expect(find.text('Payment in progress'), findsOneWidget);
    expect(tester.state(allTransitions), same(instance));
    expect(tester.getRect(find.byType(BullPaymentViewSwitch)), selector);
    tester
        .widget<BullPaymentViewSwitch>(find.byType(BullPaymentViewSwitch))
        .onStatus();
    await tester.pump();
    expect(tester.state(allTransitions), same(instance));
    expect(tester.getRect(find.byType(BullPaymentViewSwitch)), selector);
    expect(
      tester
          .widget<BullPaymentAnimation>(find.byType(BullPaymentAnimation))
          .phase,
      BullPaymentPhase.sending,
    );
  });

  for (final status in [PayjoinStatus.expired, PayjoinStatus.aborted]) {
    testWidgets('details retains the $status explanation and action', (
      tester,
    ) async {
      final now = DateTime.now();
      final bloc = _Bloc(
        ReceiveState(
          type: ReceiveType.bitcoin,
          payjoin: PayjoinReceiverSession(
            status: status,
            id: 'session',
            network: BitcoinNetwork.regtest,
            walletId: 'wallet',
            createdAt: now.subtract(const Duration(hours: 1)),
            expiresAt: now.add(const Duration(minutes: 30)),
            payjoinUri: 'https://example.com',
            hasOriginalTransaction: true,
          ),
          showPaymentAnimations: true,
        ),
      );
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.dark),
          localizationsDelegates: const [
            bullUiLocalizationsDelegate,
            ReceiveLocalizations.delegate,
            TransactionsLocalizations.delegate,
          ],
          supportedLocales: ReceiveLocalizations.supportedLocales,
          home: BlocProvider<ReceiveBloc>.value(
            value: bloc,
            child: ReceivePayjoinInProgressScreen(openHome: (_) {}),
          ),
        ),
      );
      tester
          .widget<BullPaymentViewSwitch>(find.byType(BullPaymentViewSwitch))
          .onDetails();
      await tester.pump();
      expect(
        find.text(
          status == PayjoinStatus.expired
              ? 'Payjoin timed out'
              : 'Received Without Payjoin',
        ),
        findsOneWidget,
      );
      expect(
        find.byType(ReceiveBroadcastPayjoinButton),
        status == PayjoinStatus.expired ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('details retains the fallback countdown', (tester) async {
    final now = DateTime.now();
    final bloc = _Bloc(
      ReceiveState(
        type: ReceiveType.bitcoin,
        payjoin: PayjoinReceiverSession(
          status: PayjoinStatus.requested,
          id: 'session',
          network: BitcoinNetwork.regtest,
          walletId: 'wallet',
          createdAt: now,
          expiresAt: now.add(const Duration(minutes: 30)),
          payjoinUri: 'https://example.com',
          hasOriginalTransaction: true,
        ),
        showPaymentAnimations: true,
      ),
    );
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.dark),
        localizationsDelegates: const [
          bullUiLocalizationsDelegate,
          ReceiveLocalizations.delegate,
          TransactionsLocalizations.delegate,
        ],
        supportedLocales: ReceiveLocalizations.supportedLocales,
        home: BlocProvider<ReceiveBloc>.value(
          value: bloc,
          child: ReceivePayjoinInProgressScreen(openHome: (_) {}),
        ),
      ),
    );
    tester
        .widget<BullPaymentViewSwitch>(find.byType(BullPaymentViewSwitch))
        .onDetails();
    await tester.pump();
    expect(find.byType(BullCountdown), findsOneWidget);
    expect(find.byType(ReceiveBroadcastPayjoinButton), findsOneWidget);
  });

  testWidgets('late confirmation updates the open Payjoin transition', (
    tester,
  ) async {
    final now = DateTime.now();
    final initial = ReceiveState(
      type: ReceiveType.bitcoin,
      payjoin: PayjoinReceiverSession(
        status: PayjoinStatus.completed,
        id: 'session',
        network: BitcoinNetwork.regtest,
        walletId: 'wallet',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
        payjoinUri: 'https://example.com',
        transactionId: 'target',
        hasOriginalTransaction: true,
        hasProposal: true,
      ),
      showPaymentAnimations: true,
    );
    WalletTransaction observed(String id) => WalletTransaction(
      walletId: 'wallet',
      network: BitcoinNetwork.regtest,
      direction: WalletTransactionDirection.incoming,
      status: WalletTransactionStatus.confirmed,
      txId: id,
      amountSat: 1000,
      feeSat: 0,
      vsize: 1,
      inputs: const [],
      outputs: const [],
      isRbf: false,
    );
    final bloc = _Bloc(initial);
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.dark),
        localizationsDelegates: const [
          bullUiLocalizationsDelegate,
          ReceiveLocalizations.delegate,
          TransactionsLocalizations.delegate,
        ],
        supportedLocales: ReceiveLocalizations.supportedLocales,
        home: BlocProvider<ReceiveBloc>.value(
          value: bloc,
          child: ReceivePayjoinInProgressScreen(openHome: (_) {}),
        ),
      ),
    );
    BullPaymentTransition transition() =>
        tester.widget(find.byType(BullPaymentTransition));
    final transitionState = tester.state(find.byType(BullPaymentTransition));
    expect(transition().phase, BullPaymentPhase.sending);
    expect(find.text('Step 3 of 4 · Payment detected'), findsOneWidget);
    bloc.update(initial.copyWith(settlementTx: observed('unrelated')));
    await tester.pump();
    expect(transition().phase, BullPaymentPhase.sending);
    bloc.update(initial.copyWith(settlementTx: observed('target')));
    await tester.pump();
    expect(find.byType(ReceivePayjoinInProgressScreen), findsOneWidget);
    expect(
      tester.state(find.byType(BullPaymentTransition)),
      same(transitionState),
    );
    expect(transition().phase, BullPaymentPhase.success);
    expect(transition().progress?.completed, 3);
    expect(transition().progress?.steps.last, 'Confirmed');
    expect(find.text('Step 4 of 4 · Confirmed'), findsOneWidget);
  });

  for (final (animations, reduced, expectedView) in [
    (false, false, 'details'),
  ]) {
    testWidgets('completion respects animations=$animations reduced=$reduced', (
      tester,
    ) async {
      final now = DateTime.now();
      PayjoinReceiverSession session(PayjoinStatus status) =>
          PayjoinReceiverSession(
            status: status,
            id: 'session',
            network: BitcoinNetwork.regtest,
            walletId: 'wallet',
            createdAt: now,
            expiresAt: now.add(const Duration(hours: 24)),
            payjoinUri: 'https://example.com',
            transactionId: 'target',
            hasOriginalTransaction: true,
            hasProposal: true,
          );
      final initial = ReceiveState(
        type: ReceiveType.bitcoin,
        payjoin: session(PayjoinStatus.proposed),
        showPaymentAnimations: animations,
      );
      final bloc = _Bloc(initial);
      addTearDown(bloc.close);
      Uri? opened;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => BlocProvider<ReceiveBloc>.value(
              value: bloc,
              child: ReceivePayjoinInProgressScreen(openHome: (_) {}),
            ),
          ),
          GoRoute(
            name: TransactionsRoute.payjoinTransactionDetails.name,
            path: TransactionsRoute.payjoinTransactionDetails.path,
            builder: (_, state) {
              opened = state.uri;
              return const SizedBox();
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.themeData(AppThemeType.dark),
          localizationsDelegates: const [
            bullUiLocalizationsDelegate,
            ReceiveLocalizations.delegate,
            TransactionsLocalizations.delegate,
          ],
          supportedLocales: ReceiveLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child ?? const SizedBox(),
          ),
        ),
      );
      expect(find.byType(BullPaymentTransition), findsNothing);
      bloc.update(initial.copyWith(payjoin: session(PayjoinStatus.completed)));
      await tester.pumpAndSettle();
      expect(opened?.path, '/transaction/payjoin/session');
      expect(opened?.queryParameters['view'], expectedView);
    });
  }

  testWidgets('reduced motion keeps text progress on the receive screen', (
    tester,
  ) async {
    final now = DateTime.now();
    PayjoinReceiverSession session(PayjoinStatus status) =>
        PayjoinReceiverSession(
          status: status,
          id: 'session',
          network: BitcoinNetwork.regtest,
          walletId: 'wallet',
          createdAt: now,
          expiresAt: now.add(const Duration(hours: 1)),
          payjoinUri: 'https://example.com',
          transactionId: 'target',
          hasOriginalTransaction: true,
          hasProposal: true,
        );
    final initial = ReceiveState(
      type: ReceiveType.bitcoin,
      showPaymentAnimations: true,
      payjoin: session(PayjoinStatus.proposed),
    );
    final bloc = _Bloc(initial);
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.dark),
        localizationsDelegates: const [
          bullUiLocalizationsDelegate,
          ReceiveLocalizations.delegate,
          TransactionsLocalizations.delegate,
        ],
        supportedLocales: ReceiveLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child ?? const SizedBox(),
        ),
        home: BlocProvider<ReceiveBloc>.value(
          value: bloc,
          child: ReceivePayjoinInProgressScreen(openHome: (_) {}),
        ),
      ),
    );
    expect(find.byType(BullPaymentTransition), findsNothing);
    final completed = initial.copyWith(
      payjoin: session(PayjoinStatus.completed),
    );
    bloc.update(completed);
    await tester.pump();
    expect(find.textContaining('Payment detected'), findsOneWidget);
    expect(find.textContaining('Confirmed'), findsOneWidget);
    bloc.update(
      completed.copyWith(
        settlementTx: WalletTransaction(
          walletId: 'wallet',
          network: BitcoinNetwork.regtest,
          direction: WalletTransactionDirection.incoming,
          status: WalletTransactionStatus.confirmed,
          txId: 'target',
          amountSat: 1000,
          feeSat: 0,
          vsize: 1,
          inputs: const [],
          outputs: const [],
          isRbf: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('✓ Confirmed'), findsOneWidget);
    expect(find.byType(ReceivePayjoinInProgressScreen), findsOneWidget);
  });
}
