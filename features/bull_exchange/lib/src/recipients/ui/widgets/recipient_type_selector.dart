import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/recipients/presentation/recipient_type_l10n.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/recipient_type_text.dart';
import 'package:bull_exchange/src/recipients/presentation/recipients_bloc.dart';
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

  final Jurisdiction? selectedJurisdiction;
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
            BullPickerItem(value: type, label: type.label(context)),
        ],
        value: selectedType,
        onChanged: onTypeSelected,
      );
    }
  }
}
