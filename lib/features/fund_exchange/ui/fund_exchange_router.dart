import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/screens/fund_exchange_account_screen.dart';
import 'package:bb_mobile/features/fund_exchange/ui/screens/fund_exchange_bank_transfer_wire_screen.dart';
import 'package:bb_mobile/features/fund_exchange/ui/screens/fund_exchange_canada_post_screen.dart';
import 'package:bb_mobile/features/fund_exchange/ui/screens/fund_exchange_email_e_transfer_screen.dart';
import 'package:bb_mobile/features/fund_exchange/ui/screens/fund_exchange_online_bill_payment_screen.dart';
import 'package:bb_mobile/features/fund_exchange/ui/screens/fund_exchange_sepa_transfer_screen.dart';
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
  fundExchangeSepaTransfer('sepa-transfer'),
  fundExchangeSpeiTransfer('spei-transfer');

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
          final isApiKeyInvalid =
              context.read<ExchangeCubit>().state.isApiKeyInvalid;
          if (isApiKeyInvalid) {
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
                const FundExchangeEvent.emailETransferRequested(),
              );
              return const FundExchangeEmailETransferScreen();
            },
          ),
          GoRoute(
            name: FundExchangeRoute.fundExchangeBankTransferWire.name,
            path: FundExchangeRoute.fundExchangeBankTransferWire.path,
            builder: (context, state) {
              context.read<FundExchangeBloc>().add(
                const FundExchangeEvent.bankTransferWireRequested(),
              );
              return const FundExchangeBankTransferWireScreen();
            },
          ),
          GoRoute(
            name: FundExchangeRoute.fundExchangeOnlineBillPayment.name,
            path: FundExchangeRoute.fundExchangeOnlineBillPayment.path,
            builder: (context, state) {
              context.read<FundExchangeBloc>().add(
                const FundExchangeEvent.onlineBillPaymentRequested(),
              );
              return const FundExchangeOnlineBillPaymentScreen();
            },
          ),

          GoRoute(
            name: FundExchangeRoute.fundExchangeCanadaPost.name,
            path: FundExchangeRoute.fundExchangeCanadaPost.path,
            builder: (context, state) {
              context.read<FundExchangeBloc>().add(
                const FundExchangeEvent.canadaPostRequested(),
              );
              return const FundExchangeCanadaPostScreen();
            },
          ),
          GoRoute(
            name: FundExchangeRoute.fundExchangeSepaTransfer.name,
            path: FundExchangeRoute.fundExchangeSepaTransfer.path,
            builder: (context, state) {
              context.read<FundExchangeBloc>().add(
                const FundExchangeEvent.sepaTransferRequested(),
              );
              return const FundExchangeSepaTransferScreen();
            },
          ),
          GoRoute(
            name: FundExchangeRoute.fundExchangeSpeiTransfer.name,
            path: FundExchangeRoute.fundExchangeSpeiTransfer.path,
            builder: (context, state) {
              context.read<FundExchangeBloc>().add(
                const FundExchangeEvent.speiTransferRequested(),
              );
              return const FundExchangeSpeiTransferScreen();
            },
          ),
        ],
      ),
    ],
  );
}
