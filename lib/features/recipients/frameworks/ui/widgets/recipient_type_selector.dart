import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_type_text.dart';
import 'package:bb_mobile/features/recipients/presentation/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/public/recipient_type_label.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullDropdown, BullPickerItem, BullShapesX, Gap, BullTypographyX;

class RecipientTypeSelector extends StatelessWidget {
  const RecipientTypeSelector({
    super.key,
    this.selectedJurisdiction,
    required this.selectedType,
    required this.onTypeSelected,
  });

  final String? selectedJurisdiction;
  final RecipientType? selectedType;
  final Function(RecipientType) onTypeSelected;

  @override
  Widget build(BuildContext context) {
    // Get the possible recipient types based on the selected jurisdiction
    final options = context.select(
      (RecipientsBloc bloc) => selectedJurisdiction == null
          ? <RecipientType>{}
          : bloc.state.recipientTypesForJurisdiction(selectedJurisdiction!),
    );

    if (selectedType == null) {
      return RadioGroup<RecipientType>(
        groupValue: selectedType,
        onChanged: (value) {
          if (value != null) {
            onTypeSelected(value);
          }
        },
        child: Column(
          children: options.map((type) {
            return Column(
              children: [
                RadioListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      context.bullShapes.card,
                    ),
                    side: BorderSide(color: context.appColors.onSecondaryFixed),
                  ),
                  title: RecipientTypeText(
                    recipientType: type,
                    style: context.bullType.subtitle.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  subtitle: type == RecipientType.confidentialSepaEur
                      ? Text(
                          context.loc.recipientsTypeConfidentialSepaDescription,
                          style: context.bullType.body,
                        )
                      : null,
                  value: type,
                ),
                const Gap(16),
              ],
            );
          }).toList(),
        ),
      );
    } else {
      return BullDropdown<RecipientType>(
        items: [
          for (final type in options)
            BullPickerItem(
              value: type,
              label: recipientTypeLabel(context, type),
            ),
        ],
        value: selectedType,
        onChanged: onTypeSelected,
      );
    }
  }
}
