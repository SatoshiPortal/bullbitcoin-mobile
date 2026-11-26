import 'package:bull_exchange/src/payin/payin_spend_calls.dart';
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
        calls: (session) => sellFlowCallsOf(exchange, session, wallets),
        session: exchange.currentSession,
        accessChanges: exchange.watchAccess(),
      );
    },
    child: SellFlowShell(ui: host.ui),
  ),
);
