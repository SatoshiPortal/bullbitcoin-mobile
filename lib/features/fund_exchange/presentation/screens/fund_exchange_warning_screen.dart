import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';

import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_presentation_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class FundExchangeWarningScreen extends StatefulWidget {
  const FundExchangeWarningScreen({super.key});

  @override
  State<FundExchangeWarningScreen> createState() =>
      _FundExchangeWarningScreenState();
}

class _FundExchangeWarningScreenState extends State<FundExchangeWarningScreen> {
  bool hasConfirmedNoCoercion = false;
  late StreamSubscription<FundExchangeState> _blocSubscription;
  bool isSubmittingConsent = false;
  FundExchangePresentationError? submitConsentError;

  @override
  void initState() {
    super.initState();
    _blocSubscription = context.read<FundExchangeBloc>().stream.listen((state) {
      if (state.isSubmittingScamWarningConsent != isSubmittingConsent) {
        setState(
          () => isSubmittingConsent = state.isSubmittingScamWarningConsent,
        );
      }
      if (state.submitScamWarningConsentException != submitConsentError) {
        setState(
          () => submitConsentError = state.submitScamWarningConsentException,
        );
      }
    });
  }

  @override
  void dispose() {
    _blocSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.fundExchangeTitle),
        scrolledUnderElevation: 0.0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: FadingLinearProgress(
            height: 3,
            trigger: isSubmittingConsent,
            backgroundColor: context.appColors.surface,
            foregroundColor: context.appColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: ScrollableColumn(
          padding: const EdgeInsets.all(16.0),
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
            Text(
              context.loc.fundExchangeWarningTitle,
              style: theme.textTheme.displaySmall,
            ),
            const Gap(8.0),
            Text(
              context.loc.fundExchangeWarningDescription,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const Gap(24.0),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.loc.fundExchangeWarningTacticsTitle,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const Gap(8.0),
                    ..._getTactics(context).map(
                      (tactic) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(fontSize: 14)),
                            Expanded(
                              child: Text(
                                tactic,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(24.0),
            CheckboxListTile(
              tileColor: context.appColors.secondaryFixedDim,
              contentPadding: const EdgeInsets.all(8.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              value: hasConfirmedNoCoercion,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  hasConfirmedNoCoercion = value;
                });
              },
              title: Text(
                context.loc.fundExchangeWarningConfirmation,
                style: theme.textTheme.bodyLarge,
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const Spacer(),
            if (submitConsentError != null) ...[
              Text(
                context.loc.fundExchangeScamConsentError,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const Gap(8.0),
            ],
            BBButton.big(
              label: context.loc.fundExchangeContinueButton,
              disabled: !hasConfirmedNoCoercion,
              onPressed: () {
                context.read<FundExchangeBloc>().add(
                  const FundExchangeEvent.scamWarningConsentSubmitted(),
                );
              },
              bgColor: context.appColors.primary,
              textColor: context.appColors.onPrimary,
            ),
            const Gap(16.0),
          ],
        ),
      ),
    );
  }

  List<String> _getTactics(BuildContext context) => [
    context.loc.fundExchangeWarningTactic1,
    context.loc.fundExchangeWarningTactic2,
    context.loc.fundExchangeWarningTactic3,
    context.loc.fundExchangeWarningTactic4,
    context.loc.fundExchangeWarningTactic5,
    context.loc.fundExchangeWarningTactic6,
    context.loc.fundExchangeWarningTactic7,
    context.loc.fundExchangeWarningTactic8,
  ];
}
