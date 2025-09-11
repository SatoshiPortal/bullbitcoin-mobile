import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class WithdrawRecipientsFilterDropdown extends StatelessWidget {
  const WithdrawRecipientsFilterDropdown({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.allEligibleRecipients,
  });

  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  final List<Recipient> allEligibleRecipients;

  @override
  Widget build(BuildContext context) {
    final eligibleTypes =
        allEligibleRecipients
            .map((recipient) => recipient.recipientType.displayName)
            .toSet()
            .toList();
    final filterOptions = ['All types', ...eligibleTypes];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Filter recipients by types', style: context.font.bodyMedium),
        const Gap(4.0),
        SizedBox(
          height: 56,
          child: Material(
            elevation: 4,
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(4.0),
            child: Center(
              child: DropdownButtonFormField<String>(
                value: selectedFilter,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: context.colour.secondary,
                ),
                items:
                    filterOptions
                        .map(
                          (filter) => DropdownMenuItem<String>(
                            value: filter,
                            child: Text(
                              filter,
                              style: context.font.headlineSmall,
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value != null) {
                    onFilterChanged(value);
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
