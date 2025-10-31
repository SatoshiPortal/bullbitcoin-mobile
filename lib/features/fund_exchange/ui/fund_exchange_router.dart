import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/screens/fund_exchange_account_screen.dart';
import 'package:bb_mobile/features/fund_exchange/ui/screens/fund_exchange_ars_bank_transfer_screen.dart';
import 'package:bb_mobile/features/fund_exchange/ui/screens/fund_exchange_bank_transfer_wire_screen.dart';
import 'package:bb_mobile/features/fund_exchange/ui/screens/fund_exchange_canada_post_screen.dart';
import 'package:bb_mobile/features/fund_exchange/ui/screens/fund_exchange_cr_iban_crc_screen.dart';
import 'package:bb_mobile/features/fund_exchange/ui/screens/fund_exchange_cr_iban_usd_screen.dart';
import 'package:bb_mobile/features/fund_exchange/ui/screens/fund_exchange_email_e_transfer_screen.dart';
import 'package:bb_mobile/features/fund_exchange/ui/screens/fund_exchange_instant_sepa_screen.dart';
import 'package:bb_mobile/features/fund_exchange/ui/screens/fund_exchange_online_bill_payment_screen.dart';
import 'package:bb_mobile/features/fund_exchange/ui/screens/fund_exchange_regular_sepa_screen.dart';
import 'package:bb_mobile/features/fund_exchange/ui/screens/fund_exchange_sinpe_screen.dart';
import 'package:bb_mobile/features/fund_exchange/ui/screens/fund_exchange_spei_transfer_screen.dart';
import 'package:bb_mobile/features/fund_exchange/ui/screens/fund_exchange_warning_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum FundExchangeRoute {
  fundExchangeAccount('/fund-exchange-account'),
  fundExchangeWarning('warning'),
  fundExchangeEmailETransfer('email-e-transfer'),
  fundExchangeBankTransferWire('bank-transfer-wire'),
  fundExchangeOnlineBillPayment('online-bill-payment'),
  fundExchangeCanadaPost('canada-post'),
  fundExchangeInstantSepa('instant-sepa'),
  fundExchangeRegularSepa('regular-sepa'),
  fundExchangeSpeiTransfer('spei-transfer'),
  fundExchangeSinpe('sinpe'),
  fundExchangeCostaRicaIbanCrc('cr-iban-crc'),
  fundExchangeCostaRicaIbanUsd('cr-iban-usd'),
  fundExchangeArsBankTransfer('ars-bank-transfer');

  final String path;

  const FundExchangeRoute(this.path);
}

class FundExchangeRouter {
  static final route = ShellRoute(
    builder: (context, state, child) {
      return BlocProvider(
        create:
            (_) =>
                locator<FundExchangeBloc>()
                  ..add(const FundExchangeEvent.started()),
        child: child,
      );
    },
    routes: [
      GoRoute(
        name: FundExchangeRoute.fundExchangeAccount.name,
        path: FundExchangeRoute.fundExchangeAccount.path,
        builder: (context, state) {
          return const FundExchangeAccountScreen();
        },
        redirect: (context, state) {
          final notLoggedIn = context.read<ExchangeCubit>().state.notLoggedIn;
          if (notLoggedIn) {
            return ExchangeRoute.exchangeHome.path;
          }
          return null;
        },
        routes: [
          GoRoute(
            name: FundExchangeRoute.fundExchangeWarning.name,
            path: FundExchangeRoute.fundExchangeWarning.path,
            redirect: (context, state) {
              // Check if the 'method' query parameter is present and valid,
              //  else redirect to the main fund exchange account screen.
              final methodParam = state.uri.queryParameters['method'];

              if (methodParam == null) {
                return FundExchangeRoute.fundExchangeAccount.path;
              }

              final fundingMethod = FundingMethod.fromQueryParam(methodParam);
              if (fundingMethod == null) {
                return FundExchangeRoute.fundExchangeAccount.path;
              }

              return null;
            },
            builder: (context, state) {
              final methodParam = state.uri.queryParameters['method']!;
              final fundingMethod = FundingMethod.fromQueryParam(methodParam);

              return FundExchangeWarningScreen(fundingMethod: fundingMethod!);
            },
          ),
          // Added a route per funding method instead of one screen with a switch
          // statement since different funding methods have different processes.
          GoRoute(
            name: FundExchangeRoute.fundExchangeEmailETransfer.name,
            path: FundExchangeRoute.fundExchangeEmailETransfer.path,
            builder: (context, state) {
              context.read<FundExchangeBloc>().add(
                const FundExchangeEvent.fundingDetailsRequested(
                  fundingMethod: FundingMethod.emailETransfer,
                ),
              );
              return const FundExchangeEmailETransferScreen();
            },
          ),
          GoRoute(
            name: FundExchangeRoute.fundExchangeBankTransferWire.name,
            path: FundExchangeRoute.fundExchangeBankTransferWire.path,
            builder: (context, state) {
              context.read<FundExchangeBloc>().add(
                const FundExchangeEvent.fundingDetailsRequested(
                  fundingMethod: FundingMethod.bankTransferWire,
                ),
              );
              return const FundExchangeBankTransferWireScreen();
            },
          ),
          GoRoute(
            name: FundExchangeRoute.fundExchangeOnlineBillPayment.name,
            path: FundExchangeRoute.fundExchangeOnlineBillPayment.path,
            builder: (context, state) {
              context.read<FundExchangeBloc>().add(
                const FundExchangeEvent.fundingDetailsRequested(
                  fundingMethod: FundingMethod.onlineBillPayment,
                ),
              );
              return const FundExchangeOnlineBillPaymentScreen();
            },
          ),

          GoRoute(
            name: FundExchangeRoute.fundExchangeCanadaPost.name,
            path: FundExchangeRoute.fundExchangeCanadaPost.path,
            builder: (context, state) {
              context.read<FundExchangeBloc>().add(
                const FundExchangeEvent.fundingDetailsRequested(
                  fundingMethod: FundingMethod.canadaPost,
                ),
              );
              return const FundExchangeCanadaPostScreen();
            },
          ),
          GoRoute(
            name: FundExchangeRoute.fundExchangeInstantSepa.name,
            path: FundExchangeRoute.fundExchangeInstantSepa.path,
            builder: (context, state) {
              context.read<FundExchangeBloc>().add(
                const FundExchangeEvent.fundingDetailsRequested(
                  fundingMethod: FundingMethod.instantSepa,
                ),
              );
              return const FundExchangeInstantSepaScreen();
            },
          ),
          GoRoute(
            name: FundExchangeRoute.fundExchangeRegularSepa.name,
            path: FundExchangeRoute.fundExchangeRegularSepa.path,
            builder: (context, state) {
              context.read<FundExchangeBloc>().add(
                const FundExchangeEvent.fundingDetailsRequested(
                  fundingMethod: FundingMethod.regularSepa,
                ),
              );
              return const FundExchangeRegularSepaScreen();
            },
          ),
          GoRoute(
            name: FundExchangeRoute.fundExchangeSpeiTransfer.name,
            path: FundExchangeRoute.fundExchangeSpeiTransfer.path,
            builder: (context, state) {
              context.read<FundExchangeBloc>().add(
                const FundExchangeEvent.fundingDetailsRequested(
                  fundingMethod: FundingMethod.speiTransfer,
                ),
              );
              return const FundExchangeSpeiTransferScreen();
            },
          ),
          GoRoute(
            name: FundExchangeRoute.fundExchangeSinpe.name,
            path: FundExchangeRoute.fundExchangeSinpe.path,
            builder: (context, state) {
              context.read<FundExchangeBloc>().add(
                const FundExchangeEvent.fundingDetailsRequested(
                  fundingMethod: FundingMethod.sinpe,
                ),
              );
              return const FundExchangeSinpeScreen();
            },
          ),
          GoRoute(
            name: FundExchangeRoute.fundExchangeCostaRicaIbanCrc.name,
            path: FundExchangeRoute.fundExchangeCostaRicaIbanCrc.path,
            builder: (context, state) {
              context.read<FundExchangeBloc>().add(
                const FundExchangeEvent.fundingDetailsRequested(
                  fundingMethod: FundingMethod.crIbanCrc,
                ),
              );
              return const FundExchangeCrIbanCrcScreen();
            },
          ),
          GoRoute(
            name: FundExchangeRoute.fundExchangeCostaRicaIbanUsd.name,
            path: FundExchangeRoute.fundExchangeCostaRicaIbanUsd.path,
            builder: (context, state) {
              context.read<FundExchangeBloc>().add(
                const FundExchangeEvent.fundingDetailsRequested(
                  fundingMethod: FundingMethod.crIbanUsd,
                ),
              );
              return const FundExchangeCrIbanUsdScreen();
            },
          ),
          GoRoute(
            name: FundExchangeRoute.fundExchangeArsBankTransfer.name,
            path: FundExchangeRoute.fundExchangeArsBankTransfer.path,
            builder: (context, state) {
              context.read<FundExchangeBloc>().add(
                const FundExchangeEvent.fundingDetailsRequested(
                  fundingMethod: FundingMethod.arsBankTransfer,
                ),
              );
              return const FundExchangeArsBankTransferScreen();
            },
          ),
        ],
      ),
    ],
  );
}
