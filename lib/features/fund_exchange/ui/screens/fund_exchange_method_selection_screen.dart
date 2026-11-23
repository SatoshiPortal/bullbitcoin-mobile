import 'dart:async';

import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_error_text.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_canada_methods.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_costa_rica_methods.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_europe_methods.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_jurisdiction_dropdown.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_method_list_tile.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_restricted_card.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullText,
        BullFadingLinearProgress,
        BullShimmerBox,
        BullShimmerLine,
        Gap,
        BullTypographyX;

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
  FundExchangeFailure? _fundingDetailsFailure;
  FundExchangeFailure? _institutionsFailure;
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
          if (state.isLoadingFundingDetails) _fundingDetailsFailure = null;
        });
      }
      if (state.isLoadingFundingInstitutions != isLoadingFundingInstitutions) {
        setState(() {
          isLoadingFundingInstitutions = state.isLoadingFundingInstitutions;
          if (state.isLoadingFundingInstitutions) _institutionsFailure = null;
        });
      }
      if (state.getFundingDetailsFailure != _fundingDetailsFailure) {
        setState(() {
          _fundingDetailsFailure = state.getFundingDetailsFailure;
        });
      }
      if (state.listFundingInstitutionsFailure != _institutionsFailure) {
        setState(() {
          _institutionsFailure = state.listFundingInstitutionsFailure;
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
    final isFundingRestricted = context.select(
      (FundExchangeBloc bloc) =>
          bloc.state.isStarted && bloc.state.isFundingRestricted,
    );
    final isLoadingAvailability = context.select(
      (FundExchangeBloc bloc) =>
          bloc.state.isLoadingConfidentialSepaAvailability,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.fundExchangeTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: BullFadingLinearProgress(
            height: 3,
            trigger:
                isLoadingFundingDetails ||
                isLoadingFundingInstitutions ||
                isLoadingAvailability,
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
                BullText(
                  context.loc.fundExchangeAccountTitle,
                  style: context.bullType.headline,
                ),
                const Gap(8.0),
                if (isFundingRestricted) ...[
                  const Gap(16.0),
                  const FundExchangeRestrictedCard(),
                ] else ...[
                  BullText(
                    context.loc.fundExchangeAccountSubtitle,
                    style: context.bullType.subtitle.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const Gap(24.0),
                  if (jurisdiction == null)
                    const BullShimmerLine(height: 56)
                  else
                    FundExchangeJurisdictionDropdown(
                      value: jurisdiction!,
                      onChanged: (value) {
                        context.read<FundExchangeBloc>().add(
                          const FundExchangeEvent.fundingDetailsErrorCleared(
                            resetInstitutions: true,
                          ),
                        );
                        setState(() {
                          jurisdiction = value;
                          _fundingDetailsFailure = null;
                          _institutionsFailure = null;
                        });
                      },
                    ),
                  const Gap(24.0),
                  if (jurisdiction == null)
                    const BullShimmerBox(height: 200)
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
                      FundingJurisdiction.argentina =>
                        FundExchangeMethodListTile(
                          title: context.loc.fundExchangeBankTransfer,
                          subtitle:
                              context.loc.fundExchangeBankTransferSubtitle,
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
                  if (_fundingDetailsFailure != null ||
                      _institutionsFailure != null) ...[
                    const Gap(16.0),
                    FundExchangeErrorText(
                      failure: _fundingDetailsFailure ?? _institutionsFailure!,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
