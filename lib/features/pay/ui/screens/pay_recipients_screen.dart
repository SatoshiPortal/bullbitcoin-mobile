import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/segment/segmented_full.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/ui/widgets/pay_new_recipient_form.dart';
import 'package:bb_mobile/features/pay/ui/widgets/pay_recipient_list_tile.dart';
import 'package:bb_mobile/features/withdraw/ui/widgets/withdraw_recipients_filter_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

enum RecipientsTab {
  newRecipient(displayValue: 'New beneficiary'),
  myRecipients(displayValue: 'My fiat recipients');

  final String displayValue;

  const RecipientsTab({required this.displayValue});

  static RecipientsTab fromDisplayValue(String value) {
    return RecipientsTab.values.firstWhere(
      (tab) => tab.displayValue == value,
      orElse: () => RecipientsTab.myRecipients,
    );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select recipient'),
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          FadingLinearProgress(
            height: 3,
            trigger: context.select<PayBloc, bool>((bloc) {
              final state = bloc.state;
              if (state is PayRecipientInputState) {
                return state.isCreatingPayOrder || state.isCreatingNewRecipient;
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
                            'Who are you paying?',
                            style: context.font.labelMedium?.copyWith(
                              color: Colors.black,
                            ),
                          ),
                          const Gap(16.0),
                          SizedBox(
                            width: double.infinity,
                            child: BBSegmentFull(
                              items: {
                                RecipientsTab.newRecipient.displayValue,
                                RecipientsTab.myRecipients.displayValue,
                              },
                              initialValue: _selectedTab.displayValue,
                              onSelected: (value) {
                                _onTabSelected(
                                  RecipientsTab.fromDisplayValue(value),
                                );
                              },
                            ),
                          ),
                          const Gap(16.0),
                        ],
                      ),
                    ),
                    Expanded(
                      child: switch (_selectedTab) {
                        RecipientsTab.newRecipient =>
                          const PayNewRecipientForm(),
                        RecipientsTab.myRecipients => _PayRecipientsTab(
                          key: ValueKey(_selectedTab),
                        ),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayRecipientsTab extends StatefulWidget {
  const _PayRecipientsTab({super.key});

  @override
  State<_PayRecipientsTab> createState() => _PayRecipientsTabState();
}

class _PayRecipientsTabState extends State<_PayRecipientsTab> {
  late String _filterRecipientType;
  late List<Recipient> _allEligibleRecipients;
  late List<Recipient> _filteredRecipients;
  Recipient? _selectedRecipient;

  @override
  void initState() {
    super.initState();
    // Start with no filter
    _filterRecipientType = 'All types';
    _allEligibleRecipients =
        context.read<PayBloc>().state.eligibleRecipientsByCurrency;
    _filteredRecipients = _allEligibleRecipients;
  }

  void _onFilterChanged(String filter) {
    // Change the filter and update the filtered recipients
    setState(() {
      _filterRecipientType = filter;
      _filteredRecipients =
          filter == 'All types'
              ? _allEligibleRecipients
              : _allEligibleRecipients
                  .where(
                    (recipient) =>
                        recipient.recipientType.displayName ==
                        _filterRecipientType,
                  )
                  .toList();
    });
  }

  void _onRecipientSelected(Recipient? recipient) {
    setState(() {
      _selectedRecipient = recipient;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        ColoredBox(
          color: theme.scaffoldBackgroundColor,
          child: Column(
            children: [
              WithdrawRecipientsFilterDropdown(
                selectedFilter: _filterRecipientType,
                onFilterChanged: _onFilterChanged,
                allEligibleRecipients: _allEligibleRecipients,
              ),
              const Gap(16.0),
            ],
          ),
        ),
        if (_filteredRecipients.isEmpty) ...[
          const Gap(40.0),
          const Text(
            'No recipients found to pay to.',
            style: TextStyle(fontSize: 16.0, color: Colors.grey),
          ),
        ] else ...[
          Expanded(
            child: ListView.separated(
              itemBuilder: (context, index) {
                final recipient = _filteredRecipients[index];
                return Column(
                  children: [
                    PayRecipientListTile(
                      recipient: recipient,
                      selected: _selectedRecipient == recipient,
                      onTap: () {
                        _onRecipientSelected(recipient);
                      },
                    ),
                    if (index == _filteredRecipients.length - 1)
                      const Gap(24.0),
                  ],
                );
              },
              separatorBuilder: (_, _) => const Gap(8.0),
              itemCount: _filteredRecipients.length,
            ),
          ),
          _ContinueButton(
            enabled: _selectedRecipient != null,
            onPressed: () {
              if (_selectedRecipient != null) {
                context.read<PayBloc>().add(
                  PayEvent.recipientSelected(_selectedRecipient!),
                );
                // Also dispatch the continue event to transition to amount input
                context.read<PayBloc>().add(
                  const PayEvent.recipientInputContinuePressed(),
                );
              }
            },
          ),
        ],
      ],
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
      color: context.theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          const Gap(16.0),
          BBButton.big(
            label: 'Continue',
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
