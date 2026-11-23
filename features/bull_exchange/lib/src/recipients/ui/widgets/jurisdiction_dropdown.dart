import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_ui/bull_ui.dart' show BullDropdown, BullPickerItem;
import 'package:exchange/exchange.dart';
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

  final Jurisdiction? selectedJurisdiction;
  final void Function(Jurisdiction?) onChanged;
  final bool includeAllOption;

  @override
  Widget build(BuildContext context) {
    final filters = context.select(
      (RecipientsBloc bloc) => bloc.state.allowedRecipientFilters,
    );
    final jurisdictions = filters.types
        .map((type) => type.jurisdiction)
        .toSet();

    return BullDropdown<Jurisdiction?>(
      value: selectedJurisdiction,
      onChanged: onChanged,
      items: [
        if (includeAllOption && jurisdictions.length > 1)
          BullPickerItem<Jurisdiction?>(
            value: null,
            label: context.loc.recipientsJurisdictionAll,
          ),
        for (final jurisdiction in jurisdictions)
          BullPickerItem<Jurisdiction?>(
            value: jurisdiction,
            label: switch (jurisdiction) {
              Jurisdiction.canada => context.loc.recipientsJurisdictionCanada,
              Jurisdiction.europe => context.loc.recipientsJurisdictionEurope,
              Jurisdiction.mexico => context.loc.recipientsJurisdictionMexico,
              Jurisdiction.costaRica =>
                context.loc.recipientsJurisdictionCostaRica,
              Jurisdiction.argentina =>
                context.loc.recipientsJurisdictionArgentina,
              Jurisdiction.colombia =>
                context.loc.recipientsJurisdictionColombia,
            },
          ),
      ],
    );
  }
}
