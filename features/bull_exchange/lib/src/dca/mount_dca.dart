import 'package:bull_exchange/src/account/domain/usecases/get_user_summary_usecase.dart';
import 'package:bull_exchange/src/dca/domain/usecases/activate_dca_usecase.dart';
import 'package:bull_exchange/src/dca/domain/usecases/create_dca_usecase.dart';
import 'package:bull_exchange/src/dca/domain/usecases/load_dca_context_usecase.dart';
import 'package:bull_exchange/src/default_wallets/domain/usecases/get_default_wallets_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_market_rate_usecase.dart';
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
        session: exchange.currentSession,
        accessChanges: exchange.watchAccess(),
        loadContext: LoadDcaContextUsecase(exchange),
        getMarketRate: GetMarketRateUsecase(exchange),
        getDefaultWallets: GetDefaultWalletsUsecase(exchange),
        createDca: CreateDcaUsecase(exchange),
        getUserSummary: GetUserSummaryUsecase(exchange),
        activateDca: ActivateDcaUsecase(exchange),
      );
    },
    child: DcaFlowShell(payoutField: host.payoutField),
  ),
);
