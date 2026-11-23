import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_ui/bull_ui.dart' show BullDropdown, BullPickerItem;
import 'package:bull_exchange/src/recipients/presentation/recipients_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class JurisdictionsDropdown extends StatelessWidget {
  const JurisdictionsDropdown({
    super.key,
    required this.selectedJurisdiction,
    required this.onChanged,
    this.includeAllOption = false,
  });

  final String? selectedJurisdiction;
  final void Function(String?) onChanged;
  final bool includeAllOption;

  @override
  Widget build(BuildContext context) {
    final filters = context.select(
      (RecipientsBloc bloc) => bloc.state.allowedRecipientFilters,
    );
    final jurisdictions = filters.types
        .map((type) => type.jurisdictionCode)
        .toSet();

    return BullDropdown<String?>(
      value: selectedJurisdiction,
      onChanged: onChanged,
      items: [
        if (includeAllOption && jurisdictions.length > 1)
          BullPickerItem<String?>(
            value: null,
            label: context.loc.recipientsJurisdictionAll,
          ),
        for (final jurisdiction in jurisdictions)
          BullPickerItem<String?>(
            value: jurisdiction,
            label: switch (jurisdiction) {
              'CA' => context.loc.recipientsJurisdictionCanada,
              'EU' => context.loc.recipientsJurisdictionEurope,
              'MX' => context.loc.recipientsJurisdictionMexico,
              'CR' => context.loc.recipientsJurisdictionCostaRica,
              'AR' => context.loc.recipientsJurisdictionArgentina,
              'CO' => context.loc.recipientsJurisdictionColombia,
              _ => jurisdiction,
            },
          ),
      ],
    );
  }
}
