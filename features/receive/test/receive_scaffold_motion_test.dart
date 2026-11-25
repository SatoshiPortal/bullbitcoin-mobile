import 'dart:async';

import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, ScriptType;
import 'package:receive/receive.dart';
import 'package:receive/setup.dart' show ReceiveLocalizations;
import 'package:receive/src/domain/usecases/poll_receive_wallet_usecase.dart';
import 'package:receive/src/presentation/bloc/receive_bloc.dart';
import 'package:receive/src/ui/screens/receive_scaffold.dart';
import 'package:transactions/routes.dart';
import 'package:transactions/transactions.dart';

class _FakeBloc extends Fake implements ReceiveBloc {
  final _controller = StreamController<ReceiveState>.broadcast();
  ReceiveState _state = const ReceiveState();

  @override
  ReceiveState get state => _state;

  @override
  Stream<ReceiveState> get stream => _controller.stream;

  @override
  bool get isClosed => false;

  @override
  void emit(ReceiveState next) {
    _state = next;
    _controller.add(next);
  }

  @override
  Future<void> close() => _controller.close();
}

ReceiveWallet _wallet() => ReceiveWallet(
  id: 'w1',
  network: BitcoinNetwork.mainnet,
  scriptType: ScriptType.bip84,
  signsLocally: true,
  signerDevice: null,
  balanceSat: BigInt.zero,
  confirmedBalanceSat: BigInt.zero,
);

WalletTransaction _tx() => WalletTransaction(
  walletId: 'w1',
  network: BitcoinNetwork.mainnet,
  direction: WalletTransactionDirection.incoming,
  status: WalletTransactionStatus.pending,
  txId: 'tx1',
  amountSat: 1000,
  feeSat: 10,
  vsize: 140,
  inputs: const [],
  outputs: const [],
  isRbf: false,
);

void main() {
  Future<_FakeBloc> pump(WidgetTester tester, {required bool reduced}) async {
    final bloc = _FakeBloc();
    addTearDown(bloc.close);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => BlocProvider<ReceiveBloc>.value(
            value: bloc,
            child: ReceiveScaffold(
              poll: PollReceiveWalletUsecase((_, {required isActive}) async {}),
              openHome: (_) {},
              child: const SizedBox(),
            ),
          ),
        ),
        GoRoute(
          name: TransactionsRoute.transactionDetails.name,
          path: TransactionsRoute.transactionDetails.path,
          builder: (_, state) => Text(
            'details ${state.pathParameters['txId']} '
            '${state.uri.queryParameters['walletId']}',
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: MaterialApp.router(
          theme: AppTheme.themeData(AppThemeType.dark),
          localizationsDelegates: const [
            bullUiLocalizationsDelegate,
            ReceiveLocalizations.delegate,
          ],
          supportedLocales: ReceiveLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    return bloc;
  }

  ReceiveState detected() => ReceiveState(
    type: ReceiveType.bitcoin,
    wallet: _wallet(),
    tx: _tx(),
    settlementTx: _tx(),
  );

  testWidgets('reduced motion opens the transaction details at once', (
    tester,
  ) async {
    final bloc = await pump(tester, reduced: true);
    bloc.emit(detected());
    await tester.pumpAndSettle();
    expect(find.text('details tx1 w1'), findsOneWidget);
    expect(find.byType(BullPaymentTransition), findsNothing);
  });

  testWidgets('normal motion shows the transition and stays put', (
    tester,
  ) async {
    final bloc = await pump(tester, reduced: false);
    bloc.emit(detected());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(BullPaymentTransition), findsOneWidget);
    expect(find.textContaining('details tx1'), findsNothing);
  });
}
