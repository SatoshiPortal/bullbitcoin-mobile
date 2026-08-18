import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';

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
          DropdownMenuItem<String?>(
            value: null,
            child: Text(context.loc.recipientsJurisdictionAll),
          ),
        ...jurisdictions.map((jurisdiction) {
          return DropdownMenuItem<String?>(
            value: jurisdiction,
            child: Text(switch (jurisdiction) {
              'CA' => context.loc.recipientsJurisdictionCanada,
              'EU' => context.loc.recipientsJurisdictionEurope,
              'MX' => context.loc.recipientsJurisdictionMexico,
              'CR' => context.loc.recipientsJurisdictionCostaRica,
              'AR' => context.loc.recipientsJurisdictionArgentina,
              'CO' => context.loc.recipientsJurisdictionColombia,
              _ => jurisdiction,
            }),
          );
        }),
      ],
    );
  }
}
