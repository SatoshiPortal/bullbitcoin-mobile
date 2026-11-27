import 'package:bull_exchange/src/orders/domain/usecases/find_created_order_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_market_rate_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_order_usecase.dart';
import 'package:bull_exchange/src/payout/payout_requirements_runner.dart';
import 'package:bull_exchange/src/withdraw/domain/usecases/confirm_withdraw_order_usecase.dart';
import 'package:bull_exchange/src/withdraw/domain/usecases/create_withdraw_order_usecase.dart';
import 'package:bull_exchange/src/withdraw/domain/usecases/load_withdraw_context_usecase.dart';
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
            session: exchange.currentSession,
            accessChanges: exchange.watchAccess(),
            loadContext: LoadWithdrawContextUsecase(exchange),
            getMarketRate: GetMarketRateUsecase(exchange),
            createOrder: CreateWithdrawOrderUsecase(exchange),
            findCreatedOrder: FindCreatedOrderUsecase(exchange),
            confirmOrder: ConfirmWithdrawOrderUsecase(exchange),
            getOrder: GetOrderUsecase(exchange),
            requirements: PayoutRequirementsUsecases.of(exchange),
          );
        },
        child: WithdrawFlowShell(
          brandAsset: brandAsset,
          openOrder: host.openOrder,
        ),
      ),
    );
