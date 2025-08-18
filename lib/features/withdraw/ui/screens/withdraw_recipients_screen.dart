import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/coming_soon_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/segment/segmented_full.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:bb_mobile/features/withdraw/ui/widgets/withdraw_recipient_card.dart';
import 'package:bb_mobile/features/withdraw/ui/widgets/withdraw_recipients_filter_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Column(
                  children: [
                    const Gap(40.0),
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
                          _onTabSelected(RecipientsTab.fromDisplayValue(value));
                          if (value ==
                              RecipientsTab.newRecipient.displayValue) {
                            ComingSoonBottomSheet.show(
                              context,
                              description: 'Add a new recipient',
                            );
                          }
                        },
                      ),
                    ),
                    const Gap(16.0),
                  ],
                ),
              ),
              Expanded(
                child: switch (_selectedTab) {
                  RecipientsTab.newRecipient => const SizedBox.shrink(),
                  RecipientsTab.myRecipients => _WithdrawRecipientsTab(
                    key: ValueKey(_selectedTab),
                  ),
                },
              ),
            ],
          ),
        ),
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
  String? _filterRecipientType;
  Recipient? _selectedRecipient;

  void _onFilterChanged(String? filter) {
    setState(() {
      _filterRecipientType = filter;
    });
  }

  void _onRecipientsChanged(List<Recipient>? newRecipients) {
    // Reset filter if the selected type is no longer available
    if (_filterRecipientType != null &&
        _filterRecipientType != 'All types' &&
        newRecipients != null) {
      final availableTypes =
          newRecipients
              .map((recipient) => recipient.recipientType.displayName)
              .toSet();

      if (!availableTypes.contains(_filterRecipientType)) {
        setState(() {
          _filterRecipientType = null;
        });
      }
    }
  }

  void _onRecipientSelected(Recipient? recipient) {
    setState(() {
      _selectedRecipient = recipient;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipients = context.select((WithdrawBloc bloc) {
      List<Recipient>? allRecipients;
      FiatCurrency? currency;
      final state = bloc.state;
      switch (state) {
        case WithdrawRecipientInputState():
          allRecipients = state.recipients;
          currency = state.currency;
        case WithdrawConfirmationState():
          allRecipients = state.recipients;
          currency = state.currency;
        default:
          break;
      }

      if (allRecipients == null) return null;

      // Filter recipients based on the selected filter and the currency
      if (_filterRecipientType == null || _filterRecipientType == 'All types') {
        // Show all recipients for the current currency
        final paymentProcessorsForCurrency =
            WithdrawRecipientType.values
                .where((pp) => pp.currencyCode == currency?.code)
                .toList();
        return allRecipients
            .where(
              (recipient) => paymentProcessorsForCurrency.any(
                (pp) => recipient.recipientType.code == pp.code,
              ),
            )
            .toList();
      } else {
        // Filter by specific recipient type
        final selectedType = WithdrawRecipientType.values.firstWhere(
          (type) => type.displayName == _filterRecipientType,
          orElse: () => WithdrawRecipientType.interacEmailCad,
        );

        return allRecipients
            .where((recipient) => recipient.recipientType == selectedType)
            .toList();
      }
    });

    // Check if recipients changed and reset filter if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onRecipientsChanged(recipients);
    });

    return Column(
      children: [
        ColoredBox(
          color: theme.scaffoldBackgroundColor,
          child: Column(
            children: [
              WithdrawRecipientsFilterDropdown(
                selectedFilter: _filterRecipientType,
                onFilterChanged: _onFilterChanged,
                recipients: recipients,
              ),
              const Gap(16.0),
            ],
          ),
        ),
        if (recipients == null) ...[
          const LoadingBoxContent(
            padding: EdgeInsets.zero,
            height: 200,
            width: double.infinity,
          ),
        ] else if (recipients.isEmpty) ...[
          const Gap(40.0),
          const Text(
            'No recipients found to withdraw to.',
            style: TextStyle(fontSize: 16.0, color: Colors.grey),
          ),
        ] else ...[
          Expanded(
            child: ListView.separated(
              itemBuilder: (context, index) {
                final recipient = recipients[index];
                return Column(
                  children: [
                    WithdrawRecipientCard(
                      recipient: recipient,
                      selected: _selectedRecipient == recipient,
                      onTap: () {
                        _onRecipientSelected(recipient);
                      },
                    ),
                    if (index == recipients.length - 1) const Gap(24.0),
                  ],
                );
              },
              separatorBuilder: (_, _) => const Gap(8.0),
              itemCount: recipients.length,
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
          if (isCreatingWithdrawOrder)
            const Center(child: CircularProgressIndicator()),
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
