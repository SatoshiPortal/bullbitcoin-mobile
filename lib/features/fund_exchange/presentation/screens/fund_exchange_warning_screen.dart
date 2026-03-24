import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';

import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_presentation_error.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/widgets/fund_exchange_scam_warning_card.dart';
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
  bool _hasConfirmedNoCoercion = false;
  late StreamSubscription<FundExchangeState> _blocSubscription;
  bool _isSubmittingConsent = false;
  FundExchangePresentationError? _submitConsentError;

  @override
  void initState() {
    super.initState();
    _blocSubscription = context.read<FundExchangeBloc>().stream.listen((state) {
      if (state.isSubmittingScamWarningConsent != _isSubmittingConsent) {
        setState(
          () => _isSubmittingConsent = state.isSubmittingScamWarningConsent,
        );
      }
      if (state.submitScamWarningConsentException != _submitConsentError) {
        setState(
          () => _submitConsentError = state.submitScamWarningConsentException,
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
            trigger: _isSubmittingConsent,
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
            const FundExchangeScamWarningCard(),
            const Gap(24.0),
            CheckboxListTile(
              tileColor: context.appColors.secondaryFixedDim,
              contentPadding: const EdgeInsets.all(8.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              value: _hasConfirmedNoCoercion,
              onChanged: _isSubmittingConsent
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _hasConfirmedNoCoercion = value;
                      });
                    },
              title: Text(
                context.loc.fundExchangeWarningConfirmation,
                style: theme.textTheme.bodyLarge,
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const Spacer(),
            if (_submitConsentError != null) ...[
              Text(
                context.loc.fundExchangeScamConsentError,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const Gap(8.0),
            ],
            BBButton.big(
              label: context.loc.fundExchangeContinueButton,
              disabled: !_hasConfirmedNoCoercion || _isSubmittingConsent,
              onPressed: () {
                if (_hasConfirmedNoCoercion) {
                  context.read<FundExchangeBloc>().add(
                    const FundExchangeEvent.scamWarningConsentSubmitted(),
                  );
                }
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
}
