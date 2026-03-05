import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/fund_exchange_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class FundExchangeMethodListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final FundingMethod method;

  const FundExchangeMethodListTile({
    super.key,
    required this.method,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      tileColor: context.appColors.transparent,
      shape: const RoundedRectangleBorder(),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.labelMedium!.copyWith(
          color: context.appColors.outline,
        ),
      ),
      onTap: () {
        final hasConsented =
            context.read<FundExchangeBloc>().state.userSummary
                ?.hasConsentedScamWarning ??
            false;

        if (hasConsented) {
          _navigateToFundingMethod(context, method);
        } else {
          // Reset checkbox state before showing the scam consent screen
          context.read<FundExchangeBloc>().add(
            const FundExchangeEvent.noCoercionConfirmed(false),
          );
          _navigateToScamConsentScreen(context, method);
        }
      },
      trailing: const Icon(Icons.arrow_forward),
    );
  }

  void _navigateToScamConsentScreen(
    BuildContext context,
    FundingMethod method,
  ) {
    context.pushNamed(
      FundExchangeRoute.fundExchangeScamConsent.name,
      queryParameters: {'method': method.queryParam},
    );
  }

  void _navigateToFundingMethod(BuildContext context, FundingMethod method) {
    switch (method) {
      case FundingMethod.emailETransfer:
        context.pushNamed(FundExchangeRoute.fundExchangeEmailETransfer.name);
      case FundingMethod.bankTransferWire:
        context.pushNamed(FundExchangeRoute.fundExchangeBankTransferWire.name);
      case FundingMethod.onlineBillPayment:
        context.pushNamed(
          FundExchangeRoute.fundExchangeOnlineBillPayment.name,
        );
      case FundingMethod.canadaPost:
        context.pushNamed(FundExchangeRoute.fundExchangeCanadaPost.name);
      case FundingMethod.instantSepa:
        context.pushNamed(FundExchangeRoute.fundExchangeInstantSepa.name);
      case FundingMethod.regularSepa:
        context.pushNamed(FundExchangeRoute.fundExchangeRegularSepa.name);
      case FundingMethod.speiTransfer:
        context.pushNamed(FundExchangeRoute.fundExchangeSpeiTransfer.name);
      case FundingMethod.sinpe:
        context.pushNamed(FundExchangeRoute.fundExchangeSinpe.name);
      case FundingMethod.crIbanCrc:
        context.pushNamed(
          FundExchangeRoute.fundExchangeCostaRicaIbanCrc.name,
        );
      case FundingMethod.crIbanUsd:
        context.pushNamed(
          FundExchangeRoute.fundExchangeCostaRicaIbanUsd.name,
        );
      case FundingMethod.arsBankTransfer:
        context.pushNamed(FundExchangeRoute.fundExchangeArsBankTransfer.name);
    }
  }
}
