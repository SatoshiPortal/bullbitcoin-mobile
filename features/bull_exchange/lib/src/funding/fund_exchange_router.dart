import 'package:bull_exchange/src/funding/data/url_launcher_external_link_adapter.dart';
import 'package:bull_exchange/src/funding/domain/usecases/get_cop_funding_institutions_usecase.dart';
import 'package:bull_exchange/src/funding/domain/usecases/get_funding_account_usecase.dart';
import 'package:bull_exchange/src/funding/domain/usecases/get_funding_consent_usecase.dart';
import 'package:bull_exchange/src/funding/domain/usecases/get_funding_instructions_usecase.dart';
import 'package:bull_exchange/src/funding/domain/usecases/open_funding_payment_link_usecase.dart';
import 'package:bull_exchange/src/funding/domain/usecases/save_funding_consent_usecase.dart';
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
            session: exchange.currentSession,
            accessChanges: exchange.watchAccess(),
            getAccount: GetFundingAccountUsecase(exchange),
            saveConsent: SaveFundingConsentUsecase(exchange),
            getConsent: GetFundingConsentUsecase(exchange),
            getInstitutions: GetCopFundingInstitutionsUsecase(exchange),
            getInstructions: GetFundingInstructionsUsecase(exchange),
          );
        },
        child: const FundFlowShell(
          openLink: OpenFundingPaymentLinkUsecase(
            externalLink: UrlLauncherExternalLinkAdapter(),
          ),
        ),
      ),
    ),
  ];
}
