import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/widgets/fund_exchange_details_error_card.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/widgets/fund_exchange_done_bottom_navigation_bar.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class FundExchangeCopBankTransferScreen extends StatelessWidget {
  const FundExchangeCopBankTransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final details = context.select(
      (FundExchangeBloc bloc) => bloc.state.fundingDetails,
    );
    final failedToLoadFundingDetails = context.select(
      (FundExchangeBloc bloc) => bloc.state.failedToLoadFundingDetails,
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.fundExchangeTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (failedToLoadFundingDetails ||
                    details is! CopBankTransferFundingDetails) ...[
                  const FundExchangeDetailsErrorCard(),
                  const Gap(24.0),
                ] else ...[
                  Text(
                    context.loc.fundExchangeCopRedirectMessage,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const Gap(24.0),
                  BBButton.big(
                    label: context.loc.fundExchangeCopOpenPaymentLink,
                    iconData: Icons.open_in_new,
                    onPressed: () {
                      launchUrl(
                        Uri.parse(details.paymentLink),
                        mode: LaunchMode.inAppBrowserView,
                      );
                      context.goNamed(ExchangeRoute.exchangeHome.name);
                    },
                    bgColor: context.appColors.primary,
                    textColor: context.appColors.onPrimary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const FundExchangeDoneBottomNavigationBar(),
    );
  }
}
