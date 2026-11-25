import 'package:bull_exchange/src/dca/presentation/dca_flow_bloc.dart';
import 'package:bull_exchange/src/dca/ui/dca_flow_shell.dart';
import 'package:bull_exchange/src/dca/ui/dca_router.dart';
import 'package:bull_exchange/src/exchange_purchase_routes.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The DCA flow's one route over the host's exchange.
GoRoute mountDca(ExchangePurchaseHost host) => GoRoute(
  name: DcaRoute.dca.name,
  path: DcaRoute.dca.path,
  builder: (context, state) => BlocProvider(
    create: (_) {
      final exchange = host.exchange();
      return DcaFlowBloc(
        calls: (session) => dcaFlowCallsOf(exchange, session),
        session: exchange.currentSession,
        accessChanges: exchange.watchAccess(),
      );
    },
    child: DcaFlowShell(payoutField: host.payoutField),
  ),
);
