import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class PayRecipientsFilterDropdown extends StatelessWidget {
  const PayRecipientsFilterDropdown({
    super.key,
    required this.selectedTypeFilter,
    required this.selectedCountryFilter,
    required this.onTypeFilterChanged,
    required this.onCountryFilterChanged,
    required this.allEligibleRecipients,
  });

  final String selectedTypeFilter;
  final String selectedCountryFilter;
  final ValueChanged<String> onTypeFilterChanged;
  final ValueChanged<String> onCountryFilterChanged;
  final List<Recipient> allEligibleRecipients;

  @override
  Widget build(BuildContext context) {
    // Filter recipients by selected country first
    final recipientsForCountry =
        selectedCountryFilter == 'All countries'
            ? allEligibleRecipients
            : allEligibleRecipients
                .where(
                  (recipient) =>
                      recipient.recipientType.countryCode ==
                      selectedCountryFilter,
                )
                .toList();

    // Get types available for the selected country
    final eligibleTypes =
        recipientsForCountry
            .map((recipient) => recipient.recipientType.displayName)
            .toSet()
            .toList();
    final typeOptions = ['All types', ...eligibleTypes];

    // Use the common countries list, plus "All countries"
    final countryOptions = [
      'All countries',
      ...CountryConstants.countries.map((c) => c['code']!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Country filter (top) - matches new beneficiary form
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Country',
              style: context.font.bodyLarge?.copyWith(
                color: context.colour.secondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Gap(8.0),
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: context.colour.onPrimary,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: context.colour.outline),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCountryFilter,
                  isExpanded: true,
                  hint: Text(
                    'Select country',
                    style: context.font.headlineSmall?.copyWith(
                      color: context.colour.outline,
                    ),
                  ),
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: context.colour.secondary,
                  ),
                  items:
                      countryOptions.map((countryCode) {
                        if (countryCode == 'All countries') {
                          return DropdownMenuItem<String>(
                            value: countryCode,
                            child: Text(
                              'All countries',
                              style: context.font.headlineSmall,
                            ),
                          );
                        }

                        // Find the country in the common countries list
                        final country = CountryConstants.countries.firstWhere(
                          (c) => c['code'] == countryCode,
                          orElse:
                              () => {
                                'code': countryCode,
                                'name': countryCode,
                                'flag': '',
                              },
                        );

                        return DropdownMenuItem<String>(
                          value: countryCode,
                          child: Text(
                            '${country['flag']} ${country['name']}',
                            style: context.font.headlineSmall,
                          ),
                        );
                      }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onCountryFilterChanged(value);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const Gap(16.0),
        // Type filter (bottom) - filtered by selected country
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter by type', style: context.font.bodyMedium),
            const Gap(4.0),
            SizedBox(
              height: 56,
              child: Material(
                elevation: 4,
                color: context.colour.onPrimary,
                borderRadius: BorderRadius.circular(4.0),
                child: Center(
                  child: DropdownButtonFormField<String>(
                    value: selectedTypeFilter,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                    ),
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: context.colour.secondary,
                    ),
                    items:
                        typeOptions
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
                        onTypeFilterChanged(value);
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
