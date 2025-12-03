import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_canada_methods.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_costa_rica_methods.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_europe_methods.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_jurisdiction_dropdown.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_method_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class FundExchangeAccountScreen extends StatelessWidget {
  const FundExchangeAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStarted = context.select(
      (FundExchangeBloc bloc) => bloc.state.isStarted,
    );
    final jurisdiction = context.select(
      (FundExchangeBloc bloc) => bloc.state.jurisdiction,
    );

    return Scaffold(
      appBar: AppBar(
        // Adding the leading icon button here manually since we are in the first
        // route of a shellroute and so no back button is provided by default.
        leading:
            context.canPop()
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    context.pop();
                  },
                )
                : null,
        title: Text(context.loc.fundExchangeTitle),
        scrolledUnderElevation: 0.0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              mainAxisAlignment: .center,
              crossAxisAlignment: .center,
              children: [
                const Gap(24.0),
                CircleAvatar(
                  radius: 32,
                  backgroundColor: context.appColors.surfaceContainer,
                  child: Icon(
                    Icons.account_balance,
                    size: 24,
                    color: context.appColors.onSurface,
                  ),
                ),
                const Gap(8.0),
                BBText(
                  context.loc.fundExchangeAccountTitle,
                  style: theme.textTheme.displaySmall,
                ),
                const Gap(8.0),
                BBText(
                  context.loc.fundExchangeAccountSubtitle,
                  style: theme.textTheme.headlineSmall,
                ),
                const Gap(24.0),
                if (!isStarted)
                  const LoadingLineContent(height: 56)
                else
                  const FundExchangeJurisdictionDropdown(),
                const Gap(24.0),
                if (!isStarted)
                  const LoadingBoxContent(height: 200)
                else
                  switch (jurisdiction) {
                    FundingJurisdiction.canada =>
                      const FundExchangeCanadaMethods(),
                    FundingJurisdiction.europe =>
                      const FundExchangeEuropeMethods(),
                    FundingJurisdiction.mexico => FundExchangeMethodListTile(
                      method: FundingMethod.speiTransfer,
                      title: context.loc.fundExchangeSpeiTransfer,
                      subtitle: context.loc.fundExchangeSpeiSubtitle,
                    ),
                    FundingJurisdiction.costaRica =>
                      const FundExchangeCostaRicaMethods(),
                    FundingJurisdiction.argentina => FundExchangeMethodListTile(
                      method: FundingMethod.arsBankTransfer,
                      title: context.loc.fundExchangeBankTransfer,
                      subtitle: context.loc.fundExchangeBankTransferSubtitle,
                    ),
                  },
              ],
            ),
          ),
        ),
      ),
    );
  }
}
