import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/fund_exchange/domain/primitives/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_presentation_error.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/widgets/fund_exchange_canada_methods.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/widgets/fund_exchange_costa_rica_methods.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/widgets/fund_exchange_europe_methods.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/widgets/fund_exchange_jurisdiction_dropdown.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/widgets/fund_exchange_method_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class FundExchangeMethodSelectionScreen extends StatefulWidget {
  const FundExchangeMethodSelectionScreen({super.key});

  @override
  State<FundExchangeMethodSelectionScreen> createState() =>
      _FundExchangeMethodSelectionScreenState();
}

class _FundExchangeMethodSelectionScreenState
    extends State<FundExchangeMethodSelectionScreen> {
  FundingJurisdiction? jurisdiction;
  bool isLoadingFundingDetails = false;
  bool isLoadingFundingInstitutions = false;
  FundExchangePresentationError? _fundingDetailsError;
  FundExchangePresentationError? _institutionsError;
  late final StreamSubscription<FundExchangeState> _blocSubscription;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<FundExchangeBloc>();
    if (bloc.state.isStarted) {
      jurisdiction = bloc.state.initialFundingJurisdiction;
    }
    _blocSubscription = bloc.stream.listen((state) {
      if (state.isStarted && jurisdiction == null) {
        setState(() {
          jurisdiction = state.initialFundingJurisdiction;
        });
      }
      if (state.isLoadingFundingDetails != isLoadingFundingDetails) {
        setState(() {
          isLoadingFundingDetails = state.isLoadingFundingDetails;
          if (state.isLoadingFundingDetails) _fundingDetailsError = null;
        });
      }
      if (state.isLoadingFundingInstitutions != isLoadingFundingInstitutions) {
        setState(() {
          isLoadingFundingInstitutions = state.isLoadingFundingInstitutions;
          if (state.isLoadingFundingInstitutions) _institutionsError = null;
        });
      }
      if (state.getExchangeFundingDetailsException != _fundingDetailsError) {
        setState(() {
          _fundingDetailsError = state.getExchangeFundingDetailsException;
        });
      }
      if (state.listFundingInstitutionsException != _institutionsError) {
        setState(() {
          _institutionsError = state.listFundingInstitutionsException;
        });
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: FadingLinearProgress(
            height: 3,
            trigger: isLoadingFundingDetails || isLoadingFundingInstitutions,
            backgroundColor: context.appColors.surface,
            foregroundColor: context.appColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
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
                if (jurisdiction == null)
                  const LoadingLineContent(height: 56)
                else
                  FundExchangeJurisdictionDropdown(
                    initialValue: jurisdiction!,
                    onChanged: (value) {
                      setState(() {
                        jurisdiction = value;
                      });
                    },
                  ),
                const Gap(24.0),
                if (jurisdiction == null)
                  const LoadingBoxContent(height: 200)
                else
                  switch (jurisdiction!) {
                    FundingJurisdiction.canada =>
                      const FundExchangeCanadaMethods(),
                    FundingJurisdiction.europe =>
                      const FundExchangeEuropeMethods(),
                    FundingJurisdiction.mexico => FundExchangeMethodListTile(
                      title: context.loc.fundExchangeSpeiTransfer,
                      subtitle: context.loc.fundExchangeSpeiSubtitle,
                      onTap: () {
                        context.read<FundExchangeBloc>().add(
                          const FundExchangeEvent.fundingDetailsRequested(
                            fundingMethod: SpeiTransfer(),
                          ),
                        );
                      },
                    ),
                    FundingJurisdiction.costaRica =>
                      const FundExchangeCostaRicaMethods(),
                    FundingJurisdiction.argentina => FundExchangeMethodListTile(
                      title: context.loc.fundExchangeBankTransfer,
                      subtitle: context.loc.fundExchangeBankTransferSubtitle,
                      onTap: () {
                        context.read<FundExchangeBloc>().add(
                          const FundExchangeEvent.fundingDetailsRequested(
                            fundingMethod: ArsBankTransfer(),
                          ),
                        );
                      },
                    ),
                    FundingJurisdiction.colombia => FundExchangeMethodListTile(
                      title: context.loc.fundExchangeBankTransfer,
                      subtitle: context.loc.fundExchangeBankTransferSubtitle,
                      onTap: () {
                        context.read<FundExchangeBloc>().add(
                          const FundExchangeEvent.fundingInstitutionsRequested(
                            jurisdiction: FundingJurisdiction.colombia,
                          ),
                        );
                      },
                    ),
                  },
                if (_fundingDetailsError != null || _institutionsError != null) ...[
                  const Gap(16.0),
                  BBText(
                    context.loc.fundExchangeErrorLoadingDetails,
                    style: theme.textTheme.bodyMedium,
                    color: theme.colorScheme.error,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
