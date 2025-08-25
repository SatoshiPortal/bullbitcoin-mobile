import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class WithdrawRecipientsFilterDropdown extends StatelessWidget {
  const WithdrawRecipientsFilterDropdown({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.recipients,
  });

  final String? selectedFilter;
  final ValueChanged<String?> onFilterChanged;
  final List<Recipient>? recipients;

  @override
  Widget build(BuildContext context) {
    final filterOptions = _buildFilterOptions();

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
                value: selectedFilter ?? filterOptions.first,
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
                  onFilterChanged(value);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<String> _buildFilterOptions() {
    if (recipients == null || recipients!.isEmpty) {
      return ['All types'];
    }

    // Get unique recipient types from the actual response
    final existingTypes =
        recipients!
            .map((recipient) => recipient.recipientType.displayName)
            .toSet()
            .toList();

    // Always include "All types" as the first option
    return ['All types', ...existingTypes];
  }
}
