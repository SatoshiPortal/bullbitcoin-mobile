import 'package:bull_exchange/src/funding/presentation/fund_flow_bloc.dart';
import 'package:bull_exchange/src/funding/ui/fund_flow_shell.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

typedef ExchangeFundingHost = ({Exchange Function() exchange});

/// The fund flow is one route; its steps are pages of [FundFlowShell].
enum FundExchangeRoute {
  fundExchange('/fund-exchange');

  final String path;

  const FundExchangeRoute(this.path);
}

class FundExchangeRouter {
  static List<RouteBase> routes(ExchangeFundingHost host) => [
    GoRoute(
      name: FundExchangeRoute.fundExchange.name,
      path: FundExchangeRoute.fundExchange.path,
      builder: (context, state) => BlocProvider(
        create: (_) {
          final exchange = host.exchange();
          return FundFlowBloc(
            funding: exchange.funding,
            session: exchange.currentSession,
            accessChanges: exchange.watchAccess(),
          );
        },
        child: const FundFlowShell(),
      ),
    ),
  ];
}
