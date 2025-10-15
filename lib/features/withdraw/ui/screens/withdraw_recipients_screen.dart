import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/segment/segmented_full.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:bb_mobile/features/withdraw/ui/widgets/new_recipient_form.dart';
import 'package:bb_mobile/features/withdraw/ui/widgets/withdraw_recipient_card.dart';
import 'package:bb_mobile/features/withdraw/ui/widgets/withdraw_recipients_filter_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

enum RecipientsTab {
  newRecipient(displayValue: 'New recipient'),
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

class WithdrawRecipientsScreen extends StatefulWidget {
  const WithdrawRecipientsScreen({super.key});

  @override
  State<WithdrawRecipientsScreen> createState() =>
      _WithdrawRecipientsScreenState();
}

class _WithdrawRecipientsScreenState extends State<WithdrawRecipientsScreen> {
  RecipientsTab _selectedTab = RecipientsTab.myRecipients;

  void _onTabSelected(RecipientsTab tab) {
    setState(() {
      _selectedTab = tab;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: const Text('Select recipient'),
        leading:
            context.canPop()
                ? BackButton(
                  onPressed: () {
                    context.pop();
                  },
                )
                : null,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          FadingLinearProgress(
            height: 3,
            trigger: context.select<WithdrawBloc, bool>((bloc) {
              final state = bloc.state;
              if (state is WithdrawRecipientInputState) {
                return state.isCreatingWithdrawOrder ||
                    state.isCreatingNewRecipient;
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
                            'Where and how should we send the money?',
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
                        RecipientsTab.newRecipient => const NewRecipientForm(),
                        RecipientsTab.myRecipients => _WithdrawRecipientsTab(
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

class _WithdrawRecipientsTab extends StatefulWidget {
  const _WithdrawRecipientsTab({super.key});

  @override
  State<_WithdrawRecipientsTab> createState() => _WithdrawRecipientsTabState();
}

class _WithdrawRecipientsTabState extends State<_WithdrawRecipientsTab> {
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
        context.read<WithdrawBloc>().state.eligibleRecipientsByCurrency;
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
          Text(
            'No recipients found to withdraw to.',
            style: context.font.bodyLarge?.copyWith(
              color: context.colour.outline,
            ),
          ),
        ] else ...[
          Expanded(
            child: ListView.separated(
              itemBuilder: (context, index) {
                final recipient = _filteredRecipients[index];
                return Column(
                  children: [
                    WithdrawRecipientCard(
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
                context.read<WithdrawBloc>().add(
                  WithdrawEvent.recipientSelected(_selectedRecipient!),
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
  const _ContinueButton({required this.onPressed, required this.enabled});

  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isCreatingWithdrawOrder = context.select(
      (WithdrawBloc bloc) =>
          bloc.state is WithdrawRecipientInputState &&
          (bloc.state as WithdrawRecipientInputState).isCreatingWithdrawOrder,
    );

    return ColoredBox(
      color: context.theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          const Gap(16.0),
          BBButton.big(
            label: 'Continue',
            disabled: !enabled || isCreatingWithdrawOrder,
            onPressed: onPressed,
            bgColor: context.colour.secondary,
            textColor: context.colour.onSecondary,
          ),
        ],
      ),
    );
  }
}
