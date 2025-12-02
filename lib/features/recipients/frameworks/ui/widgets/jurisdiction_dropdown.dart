import 'package:bb_mobile/core/themes/app_theme.dart';
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
            color: context.colorScheme.onSurface,
          ),
          value: selectedJurisdiction,
          onChanged: onChanged,
          items: [
            if (includeAllOption && jurisdictions.length > 1)
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All Jurisdictions'),
              ),
            ...jurisdictions.map((jurisdiction) {
              return DropdownMenuItem<String?>(
                value: jurisdiction,
                child: Text(switch (jurisdiction) {
                  'CA' => '🇨🇦 Canada',
                  'EU' => '🇪🇺 Europe (SEPA)',
                  'MX' => '🇲🇽 Mexico',
                  'CR' => '🇨🇷 Costa Rica',
                  'AR' => '🇦🇷 Argentina',
                  'CO' => '🇨🇴 Colombia',
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
