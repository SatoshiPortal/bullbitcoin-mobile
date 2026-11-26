import 'package:bull_exchange/src/orders/domain/usecases/find_created_order_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_market_rate_usecase.dart';
import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/payin/payin_spend_calls.dart';
import 'package:bull_exchange/src/payin/spend_options_runner.dart';
import 'package:bull_exchange/src/payout/payout_requirements_runner.dart';
import 'package:bull_exchange/src/sell/domain/usecases/create_sell_order_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/load_sell_context_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/refresh_sell_order_usecase.dart';
import 'package:bull_exchange/src/payin/exchange_payin_host.dart';
import 'package:bull_exchange/src/sell/presentation/sell_flow_bloc.dart';
import 'package:bull_exchange/src/sell/ui/sell_flow_shell.dart';
import 'package:bull_exchange/src/sell/ui/sell_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The sell flow's one route over the host's wallets and exchange.
GoRoute mountSell(ExchangePayinHost host) => GoRoute(
  name: SellRoute.sell.name,
  path: SellRoute.sell.path,
  builder: (context, state) => BlocProvider(
    create: (_) {
      final exchange = host.exchange();
      final wallets = (
        spend: host.spend(),
        fees: host.fees(),
        payjoinPolicy: host.payjoinPolicy(),
        payjoinSender: host.payjoinSender(),
        payjoinSessions: host.payjoinSessions(),
        labels: host.labels(),
        coins: walletCoinsOf(host.inventory(), host.native()),
      );
      return SellFlowBloc(
        session: exchange.currentSession,
        accessChanges: exchange.watchAccess(),
        loadContext: LoadSellContextUsecase(exchange),
        getMarketRate: GetMarketRateUsecase(exchange),
        createOrder: CreateSellOrderUsecase(exchange, wallets.payjoinPolicy),
        findCreatedOrder: FindCreatedOrderUsecase(exchange),
        refreshOrder: RefreshSellOrderUsecase(exchange),
        requirements: PayoutRequirementsUsecases.of(exchange),
        payin: PayinUsecases.of(exchange, wallets),
        spendOptions: SpendOptionsUsecases.of(wallets),
      );
    },
    child: SellFlowShell(ui: host.ui),
  ),
);
