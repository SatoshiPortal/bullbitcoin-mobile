import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_type_text.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class RecipientTypeSelector extends StatelessWidget {
  const RecipientTypeSelector({
    super.key,
    required this.selectedJurisdiction,
    required this.selectedType,
    required this.onTypeSelected,
  });

  final String selectedJurisdiction;
  final RecipientType? selectedType;
  final Function(RecipientType) onTypeSelected;

  @override
  Widget build(BuildContext context) {
    // Get the possible recipient types based on the selected jurisdiction
    final options = context.select(
      (RecipientsBloc bloc) =>
          bloc.state.recipientTypesForJurisdiction(selectedJurisdiction),
    );

    if (selectedType == null) {
      return Column(
        children:
            options.map((type) {
              return Column(
                children: [
                  RadioListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: context.colorScheme.onSecondaryFixed,
                      ),
                    ),
                    title: RecipientTypeText(
                      recipientType: type,
                      style: context.font.headlineSmall,
                    ),
                    value: type,
                    groupValue: selectedType,
                    onChanged: (value) {
                      if (value != null) {
                        onTypeSelected(value);
                      }
                    },
                  ),
                  const Gap(16),
                ],
              );
            }).toList(),
      );
    } else {
      return Material(
        elevation: 4,
        color: context.colorScheme.onPrimary,
        borderRadius: BorderRadius.circular(4.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: DropdownButton<RecipientType>(
            isExpanded: true,
            alignment: Alignment.centerLeft,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(4.0),
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: context.colorScheme.secondary,
            ),
            items:
                options
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
          ),
        ),
      );
    }
  }
}
