import 'package:bull_exchange/src/withdraw/presentation/withdraw_flow_bloc.dart';
import 'package:bull_exchange/src/withdraw/ui/withdraw_flow_shell.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences/preferences.dart';

/// One route: the flow's pages are a function of its state
/// ([WithdrawFlowShell]), so no sub-route takes the bloc from `state.extra`.
enum WithdrawRoute {
  withdraw('/withdraw');

  final String path;

  const WithdrawRoute(this.path);
}

typedef ExchangeWithdrawalHost = ({
  Exchange Function() exchange,
  Preferences Function() preferences,
  void Function(BuildContext, String) openOrder,
});

GoRoute withdrawRoute(ExchangeWithdrawalHost host, String brandAsset) =>
    GoRoute(
      path: WithdrawRoute.withdraw.path,
      name: WithdrawRoute.withdraw.name,
      builder: (context, state) => BlocProvider(
        create: (_) {
          final exchange = host.exchange();
          return WithdrawFlowBloc(
            calls: (session) => withdrawFlowCallsOf(exchange, session),
            session: exchange.currentSession,
            accessChanges: exchange.watchAccess(),
          );
        },
        child: WithdrawFlowShell(
          brandAsset: brandAsset,
          openOrder: host.openOrder,
        ),
      ),
    );
