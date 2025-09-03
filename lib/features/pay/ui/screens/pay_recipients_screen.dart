import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/segment/segmented_full.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/ui/widgets/pay_new_recipient_form.dart';
import 'package:bb_mobile/features/pay/ui/widgets/pay_recipient_list_tile.dart';
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
    final recipients = context.select((PayBloc bloc) {
      List<Recipient>? allRecipients;
      FiatCurrency? currency;
      final state = bloc.state;
      switch (state) {
        case PayRecipientInputState():
          allRecipients = state.recipients;
          currency = state.currency;
        case PayWalletSelectionState():
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
            'No recipients found to pay to.',
            style: TextStyle(fontSize: 16.0, color: Colors.grey),
          ),
        ] else ...[
          Expanded(
            child: ListView.separated(
              itemBuilder: (context, index) {
                final recipient = recipients[index];
                return Column(
                  children: [
                    PayRecipientListTile(
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
                context.read<PayBloc>().add(
                  PayEvent.recipientSelected(_selectedRecipient!),
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
