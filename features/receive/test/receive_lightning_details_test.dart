import 'dart:async';

import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:receive/setup.dart' show ReceiveLocalizations;
import 'package:receive/src/presentation/bloc/receive_bloc.dart';
import 'package:receive/src/ui/widgets/receive_lightning_transition.dart';
import 'package:swaps/swaps.dart'
    show Environment, LnReceiveSwap, Swap, SwapStatus, SwapType;
import 'package:transactions/routes.dart';

class _FakeBloc extends Fake implements ReceiveBloc {
  final _controller = StreamController<ReceiveState>.broadcast();

  @override
  final ReceiveState state;

  _FakeBloc(this.state);

  @override
  Stream<ReceiveState> get stream => _controller.stream;

  @override
  bool get isClosed => false;

  @override
  Future<void> close() => _controller.close();
}

void main() {
  testWidgets('the Lightning transition skip opens the details view', (
    tester,
  ) async {
    final swap = Swap.lnReceive(
      id: 'swap',
      keyIndex: 0,
      type: SwapType.lightningToLiquid,
      status: SwapStatus.claimable,
      environment: Environment.testnet,
      creationTime: DateTime.utc(2026),
      receiveWalletId: 'wallet',
      invoice: 'invoice',
    ) as LnReceiveSwap;
    final bloc = _FakeBloc(
      ReceiveState(type: ReceiveType.lightning, lightningSwap: swap),
    );
    addTearDown(bloc.close);
    final opened = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<ReceiveBloc>.value(
            value: bloc,
            child: const Scaffold(body: ReceiveLightningTransition()),
          ),
        ),
        GoRoute(
          name: TransactionsRoute.swapTransactionDetails.name,
          path: TransactionsRoute.swapTransactionDetails.path,
          builder: (_, state) {
            opened.add(state.uri.toString());
            return const Text('details');
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.themeData(AppThemeType.dark),
        localizationsDelegates: const [
          bullUiLocalizationsDelegate,
          ReceiveLocalizations.delegate,
        ],
        supportedLocales: ReceiveLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    tester
        .widget<BullPaymentTransition>(find.byType(BullPaymentTransition))
        .onSkip!();
    await tester.pumpAndSettle();
    expect(opened, hasLength(1));
    expect(opened.single, contains('view=details'));
  });
}
