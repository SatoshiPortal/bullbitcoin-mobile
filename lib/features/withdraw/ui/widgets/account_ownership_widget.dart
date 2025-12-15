import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/widgets/text/text.dart' show BBText;
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
      crossAxisAlignment: .start,
      children: [
        BBText(
          context.loc.withdrawOwnershipQuestion,
          style: context.font.bodyLarge?.copyWith(
            color: context.appColors.secondary,
            fontWeight: .w500,
          ),
        ),
        const Gap(8),
        _buildRadioOption(
          context,
          context.loc.withdrawOwnershipMyAccount,
          'isOwner',
          true,
        ),
        const Gap(8),
        _buildRadioOption(
          context,
          context.loc.withdrawOwnershipOtherAccount,
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
          color: context.appColors.onPrimary,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? context.appColors.primary
                    : context.appColors.surface,
                width: 1,
              ),
            ),
            child: RadioGroup<bool>(
              groupValue: (formData[key] as String?) == 'true',
              onChanged: (_) => onFormDataChanged(key, value.toString()),
              child: Row(
                children: [
                  Radio<bool>(
                    value: value,
                    activeColor: context.appColors.primary,
                  ),
                  const Gap(8),
                  Expanded(
                    child: BBText(
                      label,
                      style: context.font.headlineSmall?.copyWith(
                        color: context.appColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
