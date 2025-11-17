import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/segment/segmented_full.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/ui/widgets/pay_new_recipient_form.dart';
import 'package:bb_mobile/features/pay/ui/widgets/pay_recipient_list_tile.dart';
import 'package:bb_mobile/features/pay/ui/widgets/pay_recipients_filter_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

enum RecipientsTab {
  newRecipient,
  myRecipients;

  String getDisplayValue(BuildContext context) {
    return switch (this) {
      RecipientsTab.newRecipient => context.loc.payNewRecipients,
      RecipientsTab.myRecipients => context.loc.payMyFiatRecipients,
    };
  }
}

class PayRecipientsScreen extends StatefulWidget {
  const PayRecipientsScreen({super.key});

  @override
  State<PayRecipientsScreen> createState() => _PayRecipientsScreenState();
}

class _PayRecipientsScreenState extends State<PayRecipientsScreen> {
  RecipientsTab _selectedTab = RecipientsTab.myRecipients;

  void _onTabSelected(RecipientsTab tab) {
    setState(() {
      _selectedTab = tab;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PayBloc, PayState, bool>(
      selector:
          (state) =>
              state is PayRecipientInputState &&
              !state.isLoadingRecipients &&
              state.userSummary == null,
      builder: (context, isLoadedWithoutUserSummary) {
        // Check if userSummary exists, if not redirect to new beneficiary tab
        if (isLoadedWithoutUserSummary) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedTab = RecipientsTab.newRecipient;
              });
            }
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(context.loc.paySelectRecipient),
            scrolledUnderElevation: 0,
          ),
          body: Column(
            children: [
              FadingLinearProgress(
                height: 3,
                trigger: context.select<PayBloc, bool>((bloc) {
                  final state = bloc.state;
                  if (state is PayRecipientInputState) {
                    return state.isCreatingPayOrder ||
                        state.isCreatingNewRecipient ||
                        state.isLoadingRecipients;
                  }
                  return false;
                }),
                backgroundColor: context.colour.onPrimary,
                foregroundColor: context.colour.primary,
              ),
              Expanded(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        ColoredBox(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: Column(
                            children: [
                              const Gap(16.0),
                              Text(
                                context.loc.payWhoAreYouPaying,
                                style: context.font.labelMedium?.copyWith(
                                  color: context.colour.secondary,
                                ),
                              ),
                              const Gap(16.0),
                              SizedBox(
                                width: double.infinity,
                                child: BBSegmentFull(
                                  items: {
                                    RecipientsTab.newRecipient.getDisplayValue(context),
                                    RecipientsTab.myRecipients.getDisplayValue(context),
                                  },
                                  initialValue: _selectedTab.getDisplayValue(context),
                                  disabledItems:
                                      isLoadedWithoutUserSummary
                                          ? {
                                            RecipientsTab
                                                .myRecipients
                                                .getDisplayValue(context),
                                          }
                                          : {},
                                  onSelected: (value) {
                                    final newTab = value == RecipientsTab.newRecipient.getDisplayValue(context)
                                        ? RecipientsTab.newRecipient
                                        : RecipientsTab.myRecipients;
                                    _onTabSelected(newTab);
                                  },
                                ),
                              ),
                              const Gap(16.0),
                            ],
                          ),
                        ),
                        BlocBuilder<PayBloc, PayState>(
                          builder:
                              (context, state) => Expanded(
                                child: switch (_selectedTab) {
                                  RecipientsTab.newRecipient =>
                                    PayNewRecipientForm(
                                      isLoading:
                                          state is PayRecipientInputState &&
                                          state.isLoadingRecipients,
                                      userSummary: state.userSummary,
                                    ),
                                  RecipientsTab.myRecipients =>
                                    _PayRecipientsTab(
                                      key: ValueKey(_selectedTab),
                                    ),
                                },
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PayRecipientsTab extends StatefulWidget {
  const _PayRecipientsTab({super.key});

  @override
  State<_PayRecipientsTab> createState() => _PayRecipientsTabState();
}

class _PayRecipientsTabState extends State<_PayRecipientsTab> {
  String _filterRecipientType = 'All types';
  String _filterCountry = 'CA';
  Recipient? _selectedRecipient;

  void _onTypeFilterChanged(String filter) {
    setState(() {
      _filterRecipientType = filter;
    });
  }

  void _onCountryFilterChanged(String filter) {
    setState(() {
      _filterCountry = filter;
      // Reset type filter when country changes
      _filterRecipientType = 'All types';
    });
  }

  List<Recipient> _applyFilters(List<Recipient> allEligibleRecipients) {
    return allEligibleRecipients.where((recipient) {
      final typeMatch =
          _filterRecipientType == 'All types' ||
          recipient.recipientType.displayName == _filterRecipientType;
      final countryMatch =
          _filterCountry == 'All countries' ||
          recipient.recipientType.countryCode == _filterCountry;
      return typeMatch && countryMatch;
    }).toList();
  }

  void _onRecipientSelected(Recipient? recipient) {
    setState(() {
      _selectedRecipient = recipient;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<PayBloc, PayState>(
      builder: (context, state) {
        final allEligibleRecipients = state.recipients;
        final filteredRecipients = _applyFilters(allEligibleRecipients);
        final isLoadingRecipients =
            state is PayRecipientInputState && state.isLoadingRecipients;

        return Column(
          children: [
            ColoredBox(
              color: theme.scaffoldBackgroundColor,
              child: Column(
                children: [
                  PayRecipientsFilterDropdown(
                    selectedTypeFilter: _filterRecipientType,
                    selectedCountryFilter: _filterCountry,
                    onTypeFilterChanged: _onTypeFilterChanged,
                    onCountryFilterChanged: _onCountryFilterChanged,
                    allEligibleRecipients: allEligibleRecipients,
                  ),
                  const Gap(16.0),
                ],
              ),
            ),
            if (filteredRecipients.isEmpty && !isLoadingRecipients) ...[
              const Gap(40.0),
              Text(
                'No recipients found to pay to.',
                style: context.font.bodyLarge?.copyWith(
                  color: context.colour.outline,
                ),
              ),
            ] else if (isLoadingRecipients) ...[
              const Gap(40.0),
              Center(
                child: Text(
                  'Loading recipients...',
                  style: context.font.bodyLarge?.copyWith(
                    color: context.colour.outline,
                  ),
                ),
              ),
            ] else ...[
              Expanded(
                child: ListView.separated(
                  itemBuilder: (context, index) {
                    final recipient = filteredRecipients[index];
                    return Column(
                      children: [
                        PayRecipientListTile(
                          recipient: recipient,
                          selected: _selectedRecipient == recipient,
                          onTap: () {
                            _onRecipientSelected(recipient);
                          },
                        ),
                        if (index == filteredRecipients.length - 1)
                          const Gap(24.0),
                      ],
                    );
                  },
                  separatorBuilder: (_, _) => const Gap(8.0),
                  itemCount: filteredRecipients.length,
                ),
              ),
              _ContinueButton(
                enabled: _selectedRecipient != null,
                onPressed: () {
                  if (_selectedRecipient != null) {
                    context.read<PayBloc>().add(
                      PayEvent.recipientSelected(_selectedRecipient!),
                    );
                  }
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isCreatingPayOrder = context.select(
      (PayBloc bloc) =>
          bloc.state is PayRecipientInputState &&
          (bloc.state as PayRecipientInputState).isCreatingPayOrder,
    );

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          const Gap(16.0),
          BBButton.big(
            label: context.loc.payContinue,
            disabled: !enabled || isCreatingPayOrder,
            onPressed: onPressed,
            bgColor: context.colour.secondary,
            textColor: context.colour.onSecondary,
          ),
        ],
      ),
    );
  }
}
