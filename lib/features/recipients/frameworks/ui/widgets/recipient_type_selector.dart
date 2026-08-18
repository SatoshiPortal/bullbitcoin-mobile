import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_type_text.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_segmented_button.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';

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
      return Column(
        children: options.map((type) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: BullChoiceTile(
              title: RecipientTypeText(
                recipientType: type,
                style: context.font.headlineSmall,
              ),
              selected: false,
              onTap: () => onTypeSelected(type),
            ),
          );
        }).toList(),
      );
    } else {
      return BullDropdown<RecipientType>(
        items: options
            .map(
              (type) => DropdownMenuItem<RecipientType>(
                value: type,
                child: RecipientTypeText(recipientType: type),
              ),
            )
            .toList(),
        value: selectedType,
        onChanged: (value) {
          if (value != null) {
            onTypeSelected(value);
          }
        },
      );
    }
  }
}
