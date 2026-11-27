import 'package:bull_exchange/src/orders/domain/usecases/find_created_order_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_market_rate_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_order_usecase.dart';
import 'package:bull_exchange/src/pay/domain/usecases/create_pay_order_usecase.dart';
import 'package:bull_exchange/src/pay/domain/usecases/load_pay_context_usecase.dart';
import 'package:bull_exchange/src/pay/domain/usecases/refresh_pay_order_usecase.dart';
import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/payin/payin_spend_calls.dart';
import 'package:bull_exchange/src/payin/spend_options_runner.dart';
import 'package:bull_exchange/src/payout/payout_requirements_runner.dart';
import 'package:bull_exchange/src/pay/presentation/pay_flow_bloc.dart';
import 'package:bull_exchange/src/pay/ui/pay_flow_shell.dart';
import 'package:bull_exchange/src/pay/ui/pay_router.dart';
import 'package:bull_exchange/src/payin/exchange_payin_host.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The pay flow's one route over the host's wallets and exchange.
GoRoute mountPay(ExchangePayinHost host) => GoRoute(
  name: PayRoute.pay.name,
  path: PayRoute.pay.path,
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
      return PayFlowBloc(
        session: exchange.currentSession,
        accessChanges: exchange.watchAccess(),
        loadContext: LoadPayContextUsecase(exchange),
        getMarketRate: GetMarketRateUsecase(exchange),
        createOrder: CreatePayOrderUsecase(exchange, wallets.payjoinPolicy),
        findCreatedOrder: FindCreatedOrderUsecase(exchange),
        refreshOrder: RefreshPayOrderUsecase(exchange),
        getOrder: GetOrderUsecase(exchange),
        requirements: PayoutRequirementsUsecases.of(exchange),
        payin: PayinUsecases.of(exchange, wallets),
        spendOptions: SpendOptionsUsecases.of(wallets),
      );
    },
    // The SINPE receipt card reads the payin UI for its assets.
    child: RepositoryProvider.value(
      value: host.ui,
      child: PayFlowShell(ui: host.ui),
    ),
  ),
);
