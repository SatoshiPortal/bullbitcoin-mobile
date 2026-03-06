import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/fund_exchange_router.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_scam_warning_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class FundExchangeWarningScreen extends StatelessWidget {
  const FundExchangeWarningScreen({super.key, required this.fundingMethod});

  final FundingMethod fundingMethod;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FundExchangeBloc, FundExchangeState>(
      listenWhen:
          (previous, current) =>
              !previous.scamWarningConsentSubmittedSuccessfully &&
              current.scamWarningConsentSubmittedSuccessfully,
      listener: (context, state) {
        context.read<FundExchangeBloc>().add(
          const FundExchangeEvent.scamWarningConsentNavigationHandled(),
        );
        // Use pushReplacementNamed to not go back to the warning screen
        context.pushReplacementNamed(
          FundExchangeRoute.routeNameFor(fundingMethod),
        );
      },
      builder: (context, state) {
        final theme = Theme.of(context);
        final hasConfirmedNoCoercion = state.hasConfirmedNoCoercion;
        final isLoading = state.isSubmittingScamWarningConsent;
        final error = state.scamWarningConsentError;

        return Scaffold(
          appBar: AppBar(
            title: Text(context.loc.fundExchangeTitle),
            scrolledUnderElevation: 0.0,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Gap(24.0),
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: context.appColors.tertiary,
                    child: Icon(
                      Icons.shield_outlined,
                      size: 32,
                      color: context.appColors.onSurface,
                    ),
                  ),
                  const Gap(8.0),
                  BBText(
                    context.loc.fundExchangeWarningTitle,
                    style: theme.textTheme.displaySmall,
                  ),
                  const Gap(8.0),
                  BBText(
                    context.loc.fundExchangeWarningDescription,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const Gap(24.0),
                  const FundExchangeScamWarningCard(),
                  const Gap(24.0),
                  CheckboxListTile(
                    tileColor: context.appColors.secondaryFixedDim,
                    contentPadding: const EdgeInsets.all(8.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    value: hasConfirmedNoCoercion,
                    onChanged:
                        isLoading
                            ? null
                            : (value) {
                              context.read<FundExchangeBloc>().add(
                                FundExchangeEvent.noCoercionConfirmed(
                                  value ?? false,
                                ),
                              );
                            },
                    title: BBText(
                      context.loc.fundExchangeWarningConfirmation,
                      style: theme.textTheme.bodyLarge,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (error != null) ...[
                    const Gap(16.0),
                    BBText(
                      context.loc.fundExchangeScamConsentError,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: context.appColors.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: BBButton.big(
                label: context.loc.fundExchangeContinueButton,
                disabled: !hasConfirmedNoCoercion || isLoading,
                onPressed: () {
                  context.read<FundExchangeBloc>().add(
                    const FundExchangeEvent.scamWarningConsentSubmitted(),
                  );
                },
                bgColor: context.appColors.primary,
                textColor: context.appColors.onPrimary,
              ),
            ),
          ),
        );
      },
    );
  }
}
