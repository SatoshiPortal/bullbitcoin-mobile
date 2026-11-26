import 'dart:async';
import 'dart:convert';

import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/testing.dart';
import 'package:spend/legacy_exceptions.dart';
import 'package:swap_feature/src/domain/entities/swap_wallet.dart';
import 'package:swap_feature/src/presentation/transfer_bloc.dart';
import 'package:swap_feature/src/presentation/transfer_confirm_error.dart';
import 'package:swap_feature/src/swap_l10n.dart';
import 'package:swap_feature/src/ui/pages/swap_confirm_page.dart';
import 'package:go_router/go_router.dart';
import 'package:swaps/swaps.dart';
import 'package:transactions/routes.dart';

class _MockTransferBloc extends Mock implements TransferBloc {}

/// The confirm page shows the app's swap icon, which the app bundles and this
/// member's own test run does not. Serve that one asset as a transparent pixel;
/// any other missing asset still fails.
final class _AppAssets extends CachingAssetBundle {
  static const _swapIcon = 'assets/icons/swap.png';
  static final _pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  );

  @override
  Future<ByteData> load(String key) async =>
      key == _swapIcon ? ByteData.sublistView(_pixel) : rootBundle.load(key);
}

void main() {
  testWidgets('coin selection failure dismisses the confirmation transition', (
    tester,
  ) async {
    final bloc = _MockTransferBloc();
    final states = StreamController<TransferState>.broadcast();
    addTearDown(states.close);
    final swap = Swap.chain(
      id: 'swap',
      keyIndex: 0,
      type: SwapType.bitcoinToLiquid,
      status: SwapStatus.pending,
      environment: SwapEnvironment.testnet,
      creationTime: DateTime.utc(2026),
      sendWalletId: 'wallet',
      receiveWalletId: 'receive-wallet',
      paymentAddress: 'address',
      paymentAmount: 1000,
    ) as ChainSwap;
    var state = TransferState(
      fromWallet: SwapWallet(
        walletRegistrationForTesting(
          id: 'wallet',
          network: BitcoinNetwork.testnet,
        ),
        BigInt.from(10000),
        false,
      ),
      swap: swap,
      amount: '1000',
      showPaymentAnimations: true,
    );
    when(() => bloc.state).thenAnswer((_) => state);
    when(() => bloc.canRetryRejectedOrderPayin).thenReturn(false);
    when(() => bloc.stream).thenAnswer((_) => states.stream);
    when(() => bloc.add(const TransferEvent.confirmed())).thenReturn(null);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.dark),
        locale: const Locale('en'),
        localizationsDelegates: BullUiLocalizations.localizationsDelegates,
        home: DefaultAssetBundle(
          bundle: _AppAssets(),
          child: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: BlocProvider<TransferBloc>.value(
              value: bloc,
              child: const SwapConfirmPage(),
            ),
          ),
        ),
      ),
    );
    final copy = swapCopy('en');
    final confirm = tester.widget<BullButton>(
      find.ancestor(
        of: find.text(copy.coreScreensConfirmButton),
        matching: find.byType(BullButton),
      ),
    );
    confirm.onPressed();
    confirm.onPressed();
    await tester.pump();
    verify(() => bloc.add(const TransferEvent.confirmed())).called(1);
    expect(find.byType(BullPaymentTransition), findsOneWidget);

    state = state.copyWith(isConfirming: true);
    states.add(state);
    await tester.pump();
    expect(find.byType(BullPaymentTransition), findsOneWidget);

    state = state.copyWith(
      isConfirming: false,
      txId: '',
      buildTransactionException: BuildTransactionException(
        selectedCoinsUnavailableCode,
      ),
    );
    expect(state.swapFailure, isNull);
    states.add(state);
    await tester.pump();
    await tester.pump();

    expect(find.byType(BullPaymentTransition), findsNothing);
    expect(find.text('View status'), findsNothing);
    expect(find.text(copy.coreScreensConfirmButton), findsOneWidget);
    expect(find.text(copy.sendErrorSelectedCoinsUnavailable), findsOneWidget);
  });

  Future<
    ({
      _MockTransferBloc bloc,
      StreamController<TransferState> states,
      List<String> opened,
      TransferState Function() state,
      void Function(TransferState) emit,
    })
  >
  pumpConfirm(WidgetTester tester, {required bool? animations}) async {
    final bloc = _MockTransferBloc();
    final states = StreamController<TransferState>.broadcast();
    addTearDown(states.close);
    final swap = Swap.chain(
      id: 'swap',
      keyIndex: 0,
      type: SwapType.bitcoinToLiquid,
      status: SwapStatus.pending,
      environment: SwapEnvironment.testnet,
      creationTime: DateTime.utc(2026),
      sendWalletId: 'wallet',
      receiveWalletId: 'receive-wallet',
      paymentAddress: 'address',
      paymentAmount: 1000,
    ) as ChainSwap;
    var state = TransferState(
      fromWallet: SwapWallet(
        walletRegistrationForTesting(
          id: 'wallet',
          network: BitcoinNetwork.testnet,
        ),
        BigInt.from(10000),
        false,
      ),
      swap: swap,
      amount: '1000',
      showPaymentAnimations: animations,
    );
    when(() => bloc.state).thenAnswer((_) => state);
    when(() => bloc.canRetryRejectedOrderPayin).thenReturn(false);
    when(() => bloc.stream).thenAnswer((_) => states.stream);
    when(() => bloc.add(const TransferEvent.confirmed())).thenReturn(null);
    final opened = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<TransferBloc>.value(
            value: bloc,
            child: const SwapConfirmPage(),
          ),
        ),
        GoRoute(
          name: TransactionsRoute.swapTransactionDetails.name,
          path: TransactionsRoute.swapTransactionDetails.path,
          builder: (_, routeState) {
            opened.add(routeState.uri.toString());
            return const Text('details');
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.themeData(AppThemeType.dark),
        locale: const Locale('en'),
        localizationsDelegates: BullUiLocalizations.localizationsDelegates,
        builder: (_, child) => DefaultAssetBundle(
          bundle: _AppAssets(),
          child: child ?? const SizedBox.shrink(),
        ),
        routerConfig: router,
      ),
    );
    return (
      bloc: bloc,
      states: states,
      opened: opened,
      state: () => state,
      emit: (next) {
        state = next;
        states.add(next);
      },
    );
  }

  Future<void> confirm(WidgetTester tester) async {
    final copy = swapCopy('en');
    tester
        .widget<BullButton>(
          find.ancestor(
            of: find.text(copy.coreScreensConfirmButton),
            matching: find.byType(BullButton),
          ),
        )
        .onPressed();
    await tester.pump();
  }

  testWidgets('animations off: no transition, one navigation to the details', (
    tester,
  ) async {
    final rig = await pumpConfirm(tester, animations: false);
    await tester.pumpAndSettle();
    await confirm(tester);
    expect(find.byType(BullPaymentTransition), findsNothing);
    rig.emit(rig.state().copyWith(isConfirming: true));
    await tester.pump();
    expect(rig.opened, isEmpty);
    rig.emit(rig.state().copyWith(isConfirming: false, txId: 'funding'));
    await tester.pumpAndSettle();
    expect(find.byType(BullPaymentTransition), findsNothing);
    expect(rig.opened, hasLength(1));
    expect(rig.opened.single, contains('view=details'));
  });

  testWidgets('animations off: a pre-broadcast failure stays in the flow', (
    tester,
  ) async {
    final rig = await pumpConfirm(tester, animations: false);
    await tester.pumpAndSettle();
    await confirm(tester);
    rig.emit(rig.state().copyWith(isConfirming: true));
    await tester.pump();
    rig.emit(rig.state().copyWith(isConfirming: false, txId: ''));
    await tester.pumpAndSettle();
    expect(rig.opened, isEmpty);
    expect(find.byType(BullPaymentTransition), findsNothing);
  });

  testWidgets('animations on: the confirmation transition is unchanged', (
    tester,
  ) async {
    final rig = await pumpConfirm(tester, animations: true);
    await tester.pumpAndSettle();
    await confirm(tester);
    expect(find.byType(BullPaymentTransition), findsOneWidget);
    expect(rig.opened, isEmpty);
  });

  testWidgets('unknown preference: confirmation waits for it', (tester) async {
    final rig = await pumpConfirm(tester, animations: null);
    await tester.pumpAndSettle();
    final copy = swapCopy('en');
    BullButton button() => tester.widget<BullButton>(
      find.ancestor(
        of: find.text(copy.coreScreensConfirmButton),
        matching: find.byType(BullButton),
      ),
    );
    button().onPressed();
    await tester.pump();
    verifyNever(() => rig.bloc.add(const TransferEvent.confirmed()));
    rig.emit(rig.state().copyWith(showPaymentAnimations: false));
    await tester.pumpAndSettle();
    button().onPressed();
    await tester.pump();
    verify(() => rig.bloc.add(const TransferEvent.confirmed())).called(1);
    expect(rig.opened, isEmpty);
    expect(find.byType(BullPaymentTransition), findsNothing);
  });
}
