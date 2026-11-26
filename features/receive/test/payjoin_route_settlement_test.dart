import 'dart:async';

import 'package:address_view/address_view.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, BitcoinUnit, Ok, Result, ScriptType;
import 'package:receive/receive.dart';
import 'package:receive/setup.dart' show ReceiveLocalizations;
import 'package:receive/src/domain/usecases/poll_receive_wallet_usecase.dart';
import 'package:receive/src/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:receive/src/domain/usecases/create_boltz_receive_swap_usecase.dart';
import 'package:receive/src/domain/usecases/get_receive_payjoin_policy_usecase.dart';
import 'package:receive/src/domain/usecases/get_receive_swap_route_usecase.dart';
import 'package:receive/src/domain/usecases/get_receive_wallets_usecase.dart';
import 'package:receive/src/domain/usecases/prepare_receive_address_usecase.dart';
import 'package:receive/src/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:receive/src/domain/usecases/set_receive_payjoin_enabled_usecase.dart';
import 'package:receive/src/domain/usecases/watch_payjoin_usecase.dart';
import 'package:receive/src/domain/usecases/watch_receive_order_swap_usecase.dart';
import 'package:receive/src/domain/usecases/watch_receive_payjoin_enabled_usecase.dart';
import 'package:receive/src/domain/usecases/watch_receive_payjoin_min_amount_usecase.dart';
import 'package:receive/src/domain/usecases/watch_receive_settlement_usecase.dart';
import 'package:receive/src/presentation/bloc/receive_bloc.dart';
import 'package:receive/src/ui/receive_router.dart';
import 'package:receive/src/ui/widgets/receive_polling.dart';
import 'package:swaps/swaps.dart' as swaps;
import 'package:transactions/setup.dart' show TransactionsLocalizations;
import 'package:transactions/transactions.dart';

class _Receive extends Mock implements Receive {}

class _Transactions extends Mock implements Transactions {}

class _Wallets extends Mock implements GetReceiveWalletsUsecase {}

class _Prepare extends Mock implements PrepareReceiveAddressUsecase {}

class _Route extends Mock implements GetReceiveSwapRouteUsecase {}

class _Boltz extends Mock implements CreateBoltzReceiveSwapUsecase {}

class _WatchSwap extends Mock implements swaps.WatchSwapUsecase {}

class _Pj extends Mock implements ReceiveWithPayjoinUsecase {}

class _Broadcast extends Mock implements BroadcastOriginalTransactionUsecase {}

class _WatchPj extends Mock implements WatchPayjoinUsecase {}

class _WatchOrder extends Mock implements WatchReceiveOrderSwapUsecase {}

class _WatchEnabled extends Mock implements WatchReceivePayjoinEnabledUsecase {}

class _WatchMin extends Mock implements WatchReceivePayjoinMinAmountUsecase {}

class _Policy extends Mock implements GetReceivePayjoinPolicyUsecase {}

class _SetPj extends Mock implements SetReceivePayjoinEnabledUsecase {}

ReceiveWallet _wallet() => ReceiveWallet(
  id: 'w1',
  network: BitcoinNetwork.mainnet,
  scriptType: ScriptType.bip84,
  signsLocally: true,
  signerDevice: null,
  balanceSat: BigInt.zero,
  confirmedBalanceSat: BigInt.zero,
);

WalletTransaction _tx(String id, {bool confirmed = false}) => WalletTransaction(
  walletId: 'w1',
  network: BitcoinNetwork.mainnet,
  direction: WalletTransactionDirection.incoming,
  status: confirmed
      ? WalletTransactionStatus.confirmed
      : WalletTransactionStatus.pending,
  txId: id,
  amountSat: 1000,
  feeSat: 10,
  vsize: 140,
  inputs: const [],
  outputs: const [],
  isRbf: false,
);

void main() {
  late _Transactions transactions;
  late StreamController<WalletTransaction> addressTxs;
  late StreamController<WalletTransaction> settlementTxs;

  setUpAll(() => registerFallbackValue(_wallet()));

  ReceiveBloc build() {
    final receive = _Receive();
    when(receive.addressNoteSuggestions)
        .thenAnswer((_) async => const Ok(<String>{}));
    when(
      () => receive.settings(
        mode: any(named: 'mode'),
        selectedNetwork: any(named: 'selectedNetwork'),
      ),
    ).thenAnswer(
      (_) async => const Ok(
        ReceiveDisplayPreferences(
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      ),
    );
    when(
      () => receive.convertAmount(
        amountSat: any(named: 'amountSat'),
        currencyCode: any(named: 'currencyCode'),
      ),
    ).thenAnswer((_) async => const Ok(1.0));
    when(() => receive.loadAddressNote(any()))
        .thenAnswer((_) async => const Ok(''));
    final wallets = _Wallets();
    when(() => wallets.execute(onlyBitcoin: true))
        .thenAnswer((_) async => Ok([_wallet()]));
    final prepare = _Prepare();
    when(() => prepare.execute(walletId: any(named: 'walletId'))).thenAnswer(
      (_) async => Ok(
        WalletAddress(
          walletId: 'w1',
          index: 0,
          address: 'bc1qtest',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ),
    );
    final route = _Route();
    when(route.execute).thenAnswer((_) async => swaps.SwapRoute.exchange);
    final watchSwap = _WatchSwap();
    when(() => watchSwap.execute(any()))
        .thenAnswer((_) => const Stream.empty());
    final watchPj = _WatchPj();
    when(() => watchPj.execute(ids: any(named: 'ids'))).thenAnswer(
      (_) => const Stream<Result<PayjoinSession, ReceiveFailure>>.empty(),
    );
    final enabled = _WatchEnabled();
    when(enabled.execute).thenAnswer((_) => const Stream.empty());
    final min = _WatchMin();
    when(min.execute).thenAnswer((_) => const Stream.empty());
    final policy = _Policy();
    when(policy.execute).thenAnswer(
      (_) async => const Ok((enabled: false, minimumAmountSat: 10000)),
    );
    when(
      () => transactions.watchWalletTransactionByAddress(
        walletId: any(named: 'walletId'),
        toAddress: any(named: 'toAddress'),
      ),
    ).thenAnswer((_) => addressTxs.stream);
    when(
      () => transactions.watchWalletTransactionByTxId(
        walletId: any(named: 'walletId'),
        txId: any(named: 'txId'),
      ),
    ).thenAnswer((_) => settlementTxs.stream);
    return ReceiveBloc(
      getReceiveWalletsUsecase: wallets,
      resolveEntry: (wallet) async => Ok(wallet),
      refreshAfterLightningPayment: () async {},
      receive: receive,
      pollAmountQuotes: false,
      prepareReceiveAddressUsecase: prepare,
      createReceiveOrderSwapUsecase: ({
        required wallet,
        required amountSat,
        note,
      }) async => throw UnimplementedError(),
      getReceiveSwapRouteUsecase: route,
      createBoltzReceiveSwapUsecase: _Boltz(),
      watchSwapUsecase: watchSwap,
      receiveWithPayjoinUsecase: _Pj(),
      broadcastOriginalTransactionUsecase: _Broadcast(),
      watchPayjoinUsecase: watchPj,
      transactions: transactions,
      watchReceiveSettlementUsecase: WatchReceiveSettlementUsecase(
        transactions,
      ),
      watchReceiveOrderSwapUsecase: _WatchOrder(),
      watchReceivePayjoinEnabledUsecase: enabled,
      watchReceivePayjoinMinAmountUsecase: min,
      getReceivePayjoinPolicyUsecase: policy,
      setReceivePayjoinEnabledUsecase: _SetPj(),
      wallet: _wallet(),
    );
  }

  setUp(() {
    transactions = _Transactions();
    addressTxs = StreamController<WalletTransaction>.broadcast();
    settlementTxs = StreamController<WalletTransaction>.broadcast();
  });

  tearDown(() async {
    await addressTxs.close();
    await settlementTxs.close();
  });

  testWidgets('root route polls and displays late settlement in place', (
    tester,
  ) async {
    final bloc = build();
    final now = DateTime.now();
    bloc.emit(
      ReceiveState(
        type: ReceiveType.bitcoin,
        wallet: _wallet(),
        revealedAddressGeneration: 1,
        showPaymentAnimations: true,
        payjoin: PayjoinReceiverSession(
          status: PayjoinStatus.completed,
          id: 'pj',
          network: BitcoinNetwork.mainnet,
          walletId: 'w1',
          createdAt: now,
          expiresAt: now.add(const Duration(hours: 1)),
          payjoinUri: 'https://example.com',
          transactionId: 'target',
          hasOriginalTransaction: true,
          hasProposal: true,
        ),
      ),
    );
    var polls = 0;
    final root = GlobalKey<NavigatorState>();
    final router = GoRouter(
      navigatorKey: root,
      initialLocation: '/receive/bitcoin/payjoin',
      initialExtra: bloc,
      routes: [
        ReceiveRouter.mount(
          rootNavigatorKey: root,
          createBloc: (_) => bloc,
          poll: PollReceiveWalletUsecase((id, {required isActive}) async {
            expect(id, 'w1');
            polls++;
            if (polls >= 2) settlementTxs.add(_tx('target', confirmed: true));
          }),
          openHome: (_) {},
          openPayjoinSettings: (_) {},
          successAnimation: const AssetImage('unused'),
        ),
      ],
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
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
      ),
    );
    await tester.pump();
    expect(polls, 1);
    expect(find.text('Step 3 of 4 · Payment detected'), findsOneWidget);
    final allTransitions = find.byType(
      BullPaymentTransition,
      skipOffstage: false,
    );
    final transition = tester.state(allTransitions);
    tester
        .widget<BullPaymentViewSwitch>(find.byType(BullPaymentViewSwitch))
        .onDetails();
    await tester.pump();
    expect(find.text('Payment in progress'), findsOneWidget);
    await tester.pump(ReceivePolling.receiveResyncDelay);
    await tester.pump();
    await tester.pump();
    expect(polls, 2);
    expect(bloc.state.settlementConfirmed, isTrue);
    expect(tester.state(allTransitions), same(transition));
    tester
        .widget<BullPaymentViewSwitch>(find.byType(BullPaymentViewSwitch))
        .onStatus();
    await tester.pump();
    expect(find.text('Step 4 of 4 · Confirmed'), findsOneWidget);
    expect(tester.state(allTransitions), same(transition));
    expect(
      router.routeInformationProvider.value.uri.path,
      '/receive/bitcoin/payjoin',
    );
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
}
