import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:flutter/material.dart';
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
    // Get the possible jurisdictions
    final jurisdictions = context.select(
      (RecipientsBloc bloc) => bloc.state.availableJurisdictions,
    );

    return Material(
      elevation: 4,
      shadowColor: context.appColors.onSurface.withValues(alpha: 0.7),
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(4.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: DropdownButton<String?>(
          isExpanded: true,
          alignment: Alignment.centerLeft,
          underline: const SizedBox.shrink(),
          borderRadius: BorderRadius.circular(4.0),
          dropdownColor: context.appColors.surface,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: context.appColors.onSurface,
          ),
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
        ),
      ),
    );
  }
}
