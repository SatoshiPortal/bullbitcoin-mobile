import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart' show BBText;
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class AccountOwnershipWidget extends StatelessWidget {
  const AccountOwnershipWidget({
    super.key,
    required this.formData,
    required this.onFormDataChanged,
  });

  final Map<String, dynamic> formData;
  final Function(String, String) onFormDataChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          'Who does this account belong to?',
          style: context.font.bodyLarge?.copyWith(
            color: context.colour.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(8),
        _buildRadioOption(context, 'This is my account', 'isOwner', true),
        const Gap(8),
        _buildRadioOption(
          context,
          "This is someone else's account",
          'isOwner',
          false,
        ),
      ],
    );
  }

  Widget _buildRadioOption(
    BuildContext context,
    String label,
    String key,
    bool value,
  ) {
    final isSelected = formData[key] == value;

    return InkWell(
      onTap: () => onFormDataChanged(key, value.toString()),
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 56,
        child: Material(
          elevation: 4,
          color: context.colour.onPrimary,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color:
                    isSelected
                        ? context.colour.primary
                        : context.colour.surface,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Radio<bool>(
                  value: value,
                  groupValue: (formData[key] as String?) == 'true',
                  onChanged: (_) => onFormDataChanged(key, value.toString()),
                  activeColor: context.colour.primary,
                ),
                const Gap(8),
                Expanded(
                  child: BBText(
                    label,
                    style: context.font.headlineSmall?.copyWith(
                      color: context.colour.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
