import 'package:bull_exchange/src/payin/payin_spend_calls.dart';
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
        calls: (session) => payFlowCallsOf(exchange, session, wallets),
        session: exchange.currentSession,
        accessChanges: exchange.watchAccess(),
      );
    },
    // The SINPE receipt card reads the payin UI for its assets.
    child: RepositoryProvider.value(
      value: host.ui,
      child: PayFlowShell(ui: host.ui),
    ),
  ),
);
