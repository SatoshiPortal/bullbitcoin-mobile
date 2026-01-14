import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_type_text.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/virtual_iban/presentation/virtual_iban_bloc.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class RecipientTypeSelector extends StatelessWidget {
  const RecipientTypeSelector({
    super.key,
    required this.selectedJurisdiction,
    required this.selectedType,
    required this.onTypeSelected,
    this.showVibanLabels = false,
  });

  final String selectedJurisdiction;
  final RecipientType? selectedType;
  final Function(RecipientType) onTypeSelected;

  /// When true, shows "Activate Confidential SEPA" with NEW badge
  /// for frPayee when VIBAN is not active.
  final bool showVibanLabels;

  @override
  Widget build(BuildContext context) {
    // Get the possible recipient types based on the selected jurisdiction
    var options = context.select(
      (RecipientsBloc bloc) =>
          bloc.state.recipientTypesForJurisdiction(selectedJurisdiction),
    );

    // Filter out system-managed types that shouldn't be shown to users
    options = options
        .where((type) => type != RecipientType.frVirtualAccount)
        .toSet();

    // Check VIBAN status when showing VIBAN labels
    final isVibanActive =
        showVibanLabels ? locator<VirtualIbanBloc>().state.isActive : false;

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
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: context.appColors.onSecondaryFixed),
                  ),
                  title: _buildTypeLabel(context, type, isVibanActive),
                  value: type,
                ),
                const Gap(16),
              ],
            );
          }).toList(),
        ),
      );
    } else {
      return Material(
        elevation: 4,
        color: context.appColors.onSecondary,
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
              color: context.appColors.secondary,
            ),
            items: options
                .map(
                  (type) => DropdownMenuItem<RecipientType>(
                    value: type,
                    child: _buildTypeLabel(context, type, isVibanActive),
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

  Widget _buildTypeLabel(
    BuildContext context,
    RecipientType type,
    bool isVibanActive,
  ) {
    // Special handling for frPayee (Confidential SEPA) with VIBAN labels
    if (showVibanLabels && type == RecipientType.frPayee) {
      final labelText = isVibanActive
          ? context.loc.confidentialSepaTitle
          : context.loc.activateConfidentialSepa;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              labelText,
              style: context.font.headlineSmall,
            ),
          ),
          if (!isVibanActive) ...[
            const Gap(8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.appColors.tertiaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                context.loc.newBadge.toUpperCase(),
                style: context.font.labelSmall?.copyWith(
                  color: context.appColors.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      );
    }

    // Special label for cjPayee (Regular SEPA)
    if (type == RecipientType.cjPayee) {
      return Text(
        context.loc.regularSepa,
        style: context.font.headlineSmall,
      );
    }

    // Default label
    return RecipientTypeText(
      recipientType: type,
      style: context.font.headlineSmall,
    );
  }
}
