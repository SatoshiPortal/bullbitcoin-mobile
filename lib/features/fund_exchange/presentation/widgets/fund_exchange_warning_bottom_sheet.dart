import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_presentation_error.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/widgets/fund_exchange_scam_warning_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class FundExchangeWarningBottomSheet extends StatefulWidget {
  const FundExchangeWarningBottomSheet({super.key});

  @override
  State<FundExchangeWarningBottomSheet> createState() =>
      _FundExchangeWarningBottomSheetState();
}

class _FundExchangeWarningBottomSheetState
    extends State<FundExchangeWarningBottomSheet> {
  bool _hasConfirmedNoCoercion = false;
  late StreamSubscription<FundExchangeState> _blocSubscription;
  bool _isLoading = false;
  FundExchangePresentationError? _submitConsentError;

  @override
  void initState() {
    super.initState();
    _blocSubscription = context.read<FundExchangeBloc>().stream.listen((state) {
      if (!mounted) return;
      final isLoading =
          state.isSubmittingScamWarningConsent ||
          state.isLoadingFundingDetails ||
          state.isLoadingFundingInstitutions;
      if (isLoading != _isLoading) {
        setState(() => _isLoading = isLoading);
      }
      if (state.submitScamWarningConsentException != _submitConsentError) {
        setState(
          () => _submitConsentError = state.submitScamWarningConsentException,
        );
      }
      // Close the bottom sheet once the API call triggered after consent
      // completes (successfully or with an error). The parent route's listeners
      // handle onward navigation.
      final dataReady =
          state.fundingDetails != null || state.fundingInstitutions != null;
      final dataError =
          state.getExchangeFundingDetailsException != null ||
          state.listFundingInstitutionsException != null;
      if (dataReady || dataError) {
        Navigator.of(context).pop();
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadingLinearProgress(
          height: 3,
          trigger: _isLoading,
          backgroundColor: context.appColors.surface,
          foregroundColor: context.appColors.primary,
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            16.0,
            16.0,
            16.0,
            MediaQuery.of(context).viewInsets.bottom + 16.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: context.appColors.tertiary,
                child: Icon(
                  Icons.shield_outlined,
                  size: 28,
                  color: context.appColors.onSurface,
                ),
              ),
              const Gap(8.0),
              BBText(
                context.loc.fundExchangeWarningTitle,
                style: theme.textTheme.displaySmall,
              ),
              const Gap(4.0),
              BBText(
                context.loc.fundExchangeWarningDescription,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const Gap(16.0),
              const FundExchangeScamWarningCard(),
              const Gap(16.0),
              CheckboxListTile(
                tileColor: context.appColors.secondaryFixedDim,
                contentPadding: const EdgeInsets.all(8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                value: _hasConfirmedNoCoercion,
                onChanged: _isLoading
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _hasConfirmedNoCoercion = value;
                        });
                      },
                title: BBText(
                  context.loc.fundExchangeWarningConfirmation,
                  style: theme.textTheme.bodyLarge,
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Gap(16.0),
              if (_submitConsentError != null) ...[
                BBText(
                  context.loc.fundExchangeScamConsentError,
                  style: theme.textTheme.bodyMedium,
                  color: theme.colorScheme.error,
                  textAlign: TextAlign.center,
                ),
                const Gap(8.0),
              ],
              BBButton.big(
                label: context.loc.fundExchangeContinueButton,
                disabled: !_hasConfirmedNoCoercion || _isLoading,
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
              const Gap(8.0),
            ],
          ),
        ),
      ],
    );
  }
}
