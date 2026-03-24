import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/screens/fund_exchange_cop_bank_transfer_input_screen.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/screens/fund_exchange_cop_bank_transfer_screen.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/screens/fund_exchange_method_selection_screen.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/screens/fund_exchange_ars_bank_transfer_screen.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/screens/fund_exchange_bank_transfer_wire_screen.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/screens/fund_exchange_canada_post_screen.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/screens/fund_exchange_cr_iban_crc_screen.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/screens/fund_exchange_cr_iban_usd_screen.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/screens/fund_exchange_email_e_transfer_screen.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/screens/fund_exchange_instant_sepa_screen.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/screens/fund_exchange_online_bill_payment_screen.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/screens/fund_exchange_regular_sepa_screen.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/screens/fund_exchange_sinpe_screen.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/screens/fund_exchange_spei_transfer_screen.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/screens/fund_exchange_warning_screen.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_details.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum FundExchangeRoute {
  fundExchange('/fund-exchange'),
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
  fundExchangeArsBankTransfer('ars-bank-transfer'),
  fundExchangeCopBankTransferInput('cop-bank-transfer-input'),
  fundExchangeCopBankTransfer('cop-bank-transfer');

  final String path;

  const FundExchangeRoute(this.path);
}

FundExchangeRoute _routeForFundingDetails(
  FundingDetails details,
) => switch (details) {
  ETransferFundingDetails() => FundExchangeRoute.fundExchangeEmailETransfer,
  WireFundingDetails() => FundExchangeRoute.fundExchangeBankTransferWire,
  BillPaymentFundingDetails() =>
    FundExchangeRoute.fundExchangeOnlineBillPayment,
  CanadaPostFundingDetails() => FundExchangeRoute.fundExchangeCanadaPost,
  InstantSepaFundingDetails() => FundExchangeRoute.fundExchangeInstantSepa,
  RegularSepaFundingDetails() => FundExchangeRoute.fundExchangeRegularSepa,
  SpeiFundingDetails() => FundExchangeRoute.fundExchangeSpeiTransfer,
  SinpeFundingDetails() => FundExchangeRoute.fundExchangeSinpe,
  CrIbanCrcFundingDetails() => FundExchangeRoute.fundExchangeCostaRicaIbanCrc,
  CrIbanUsdFundingDetails() => FundExchangeRoute.fundExchangeCostaRicaIbanUsd,
  ArsBankTransferFundingDetails() =>
    FundExchangeRoute.fundExchangeArsBankTransfer,
  CopBankTransferFundingDetails() =>
    FundExchangeRoute.fundExchangeCopBankTransfer,
};

void _goToFundingScreen(
  BuildContext context,
  FundExchangeBloc bloc,
  FundingDetails? fundingDetails,
) {
  if (fundingDetails == null) throw UnimplementedError();
  context.goNamed(_routeForFundingDetails(fundingDetails).name, extra: bloc);
}

class FundExchangeRouter {
  static final route = GoRoute(
    name: FundExchangeRoute.fundExchange.name,
    path: FundExchangeRoute.fundExchange.path,
    redirect: (context, state) {
      final notLoggedIn = context.read<ExchangeCubit>().state.notLoggedIn;
      if (notLoggedIn) {
        return ExchangeRoute.exchangeHome.path;
      }
      return null;
    },
    builder: (context, state) {
      return BlocProvider(
        create: (_) =>
            locator<FundExchangeBloc>()..add(const FundExchangeEvent.started()),
        child: MultiBlocListener(
          listeners: [
            BlocListener<FundExchangeBloc, FundExchangeState>(
              listenWhen: (previous, current) =>
                  previous.apiKeyException == null &&
                  current.apiKeyException != null,
              listener: (context, state) {
                context.goNamed(ExchangeRoute.exchangeHome.name);
              },
            ),
            BlocListener<FundExchangeBloc, FundExchangeState>(
              listenWhen: (previous, current) =>
                  previous.fundingInstitutions == null &&
                  current.fundingInstitutions != null,
              listener: (context, state) {
                // If more funding methods load institutions in the future,
                // this will need to check the loading funding institutions jurisdiction
                context.pushNamed(
                  FundExchangeRoute.fundExchangeCopBankTransferInput.name,
                  extra: context.read<FundExchangeBloc>(),
                );
              },
            ),
            BlocListener<FundExchangeBloc, FundExchangeState>(
              listenWhen: (previous, current) =>
                  previous.fundingDetails == null &&
                  current.fundingDetails != null,
              listener: (context, state) {
                if (state.shouldShowScamWarningConsent) {
                  // Push so going back returns to the previous screen
                  context.pushNamed(
                    FundExchangeRoute.fundExchangeWarning.name,
                    extra: context.read<FundExchangeBloc>(),
                  );
                  return;
                } else {
                  _goToFundingScreen(
                    context,
                    context.read<FundExchangeBloc>(),
                    state.fundingDetails,
                  );
                }
              },
            ),
          ],
          child: const FundExchangeMethodSelectionScreen(),
        ),
      );
    },

    routes: [
      GoRoute(
        name: FundExchangeRoute.fundExchangeWarning.name,
        path: FundExchangeRoute.fundExchangeWarning.path,
        builder: (context, state) {
          final bloc = state.extra! as FundExchangeBloc;

          return BlocProvider.value(
            value: bloc,
            child: BlocListener<FundExchangeBloc, FundExchangeState>(
              listenWhen: (previous, current) =>
                  previous.shouldShowScamWarningConsent &&
                  !current.shouldShowScamWarningConsent,
              listener: (context, state) {
                _goToFundingScreen(
                  context,
                  context.read<FundExchangeBloc>(),
                  state.fundingDetails,
                );
              },
              child: const FundExchangeWarningScreen(),
            ),
          );
        },
      ),
      // Added a route per funding method instead of one screen with a switch
      // statement since different funding methods have different processes.
      GoRoute(
        name: FundExchangeRoute.fundExchangeEmailETransfer.name,
        path: FundExchangeRoute.fundExchangeEmailETransfer.path,
        builder: (context, state) => BlocProvider.value(
          value: state.extra! as FundExchangeBloc,
          child: const FundExchangeEmailETransferScreen(),
        ),
      ),
      GoRoute(
        name: FundExchangeRoute.fundExchangeBankTransferWire.name,
        path: FundExchangeRoute.fundExchangeBankTransferWire.path,
        builder: (context, state) => BlocProvider.value(
          value: state.extra! as FundExchangeBloc,
          child: const FundExchangeBankTransferWireScreen(),
        ),
      ),
      GoRoute(
        name: FundExchangeRoute.fundExchangeOnlineBillPayment.name,
        path: FundExchangeRoute.fundExchangeOnlineBillPayment.path,
        builder: (context, state) => BlocProvider.value(
          value: state.extra! as FundExchangeBloc,
          child: const FundExchangeOnlineBillPaymentScreen(),
        ),
      ),
      GoRoute(
        name: FundExchangeRoute.fundExchangeCanadaPost.name,
        path: FundExchangeRoute.fundExchangeCanadaPost.path,
        builder: (context, state) => BlocProvider.value(
          value: state.extra! as FundExchangeBloc,
          child: const FundExchangeCanadaPostScreen(),
        ),
      ),
      GoRoute(
        name: FundExchangeRoute.fundExchangeInstantSepa.name,
        path: FundExchangeRoute.fundExchangeInstantSepa.path,
        builder: (context, state) => BlocProvider.value(
          value: state.extra! as FundExchangeBloc,
          child: const FundExchangeInstantSepaScreen(),
        ),
      ),
      GoRoute(
        name: FundExchangeRoute.fundExchangeRegularSepa.name,
        path: FundExchangeRoute.fundExchangeRegularSepa.path,
        builder: (context, state) => BlocProvider.value(
          value: state.extra! as FundExchangeBloc,
          child: const FundExchangeRegularSepaScreen(),
        ),
      ),
      GoRoute(
        name: FundExchangeRoute.fundExchangeSpeiTransfer.name,
        path: FundExchangeRoute.fundExchangeSpeiTransfer.path,
        builder: (context, state) => BlocProvider.value(
          value: state.extra! as FundExchangeBloc,
          child: const FundExchangeSpeiTransferScreen(),
        ),
      ),
      GoRoute(
        name: FundExchangeRoute.fundExchangeSinpe.name,
        path: FundExchangeRoute.fundExchangeSinpe.path,
        builder: (context, state) => BlocProvider.value(
          value: state.extra! as FundExchangeBloc,
          child: const FundExchangeSinpeScreen(),
        ),
      ),
      GoRoute(
        name: FundExchangeRoute.fundExchangeCostaRicaIbanCrc.name,
        path: FundExchangeRoute.fundExchangeCostaRicaIbanCrc.path,
        builder: (context, state) => BlocProvider.value(
          value: state.extra! as FundExchangeBloc,
          child: const FundExchangeCrIbanCrcScreen(),
        ),
      ),
      GoRoute(
        name: FundExchangeRoute.fundExchangeCostaRicaIbanUsd.name,
        path: FundExchangeRoute.fundExchangeCostaRicaIbanUsd.path,
        builder: (context, state) => BlocProvider.value(
          value: state.extra! as FundExchangeBloc,
          child: const FundExchangeCrIbanUsdScreen(),
        ),
      ),
      GoRoute(
        name: FundExchangeRoute.fundExchangeArsBankTransfer.name,
        path: FundExchangeRoute.fundExchangeArsBankTransfer.path,
        builder: (context, state) => BlocProvider.value(
          value: state.extra! as FundExchangeBloc,
          child: const FundExchangeArsBankTransferScreen(),
        ),
      ),
      GoRoute(
        name: FundExchangeRoute.fundExchangeCopBankTransferInput.name,
        path: FundExchangeRoute.fundExchangeCopBankTransferInput.path,
        builder: (context, state) => BlocProvider.value(
          value: state.extra! as FundExchangeBloc,
          child: const FundExchangeCopBankTransferInputScreen(),
        ),
        routes: [
          GoRoute(
            name: FundExchangeRoute.fundExchangeCopBankTransfer.name,
            path: FundExchangeRoute.fundExchangeCopBankTransfer.path,
            builder: (context, state) => BlocProvider.value(
              value: state.extra! as FundExchangeBloc,
              child: const FundExchangeCopBankTransferScreen(),
            ),
          ),
        ],
      ),
    ],
  );
}
