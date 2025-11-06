import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/jurisdiction_dropdown.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_type_selector.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class NewRecipientTab extends StatefulWidget {
  const NewRecipientTab({super.key});

  @override
  _NewRecipientTabState createState() => _NewRecipientTabState();
}

class _NewRecipientTabState extends State<NewRecipientTab> {
  late String _selectedJurisdiction;
  RecipientType? _selectedRecipientType;

  @override
  void initState() {
    super.initState();
    // TODO: Initialize with the user's default jurisdiction if available
    _selectedJurisdiction =
        context
            .read<RecipientsBloc>()
            .state
            .selectableRecipientTypes
            .map((t) => t.jurisdictionCode)
            .first;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JurisdictionsDropdown(
          selectedJurisdiction: _selectedJurisdiction,
          onChanged: (newJurisdiction) {
            if (newJurisdiction == null) return;
            setState(() {
              _selectedJurisdiction = newJurisdiction;
              // Reset selected type as well since for the possible types
              // depend on the selected jurisdiction
              _selectedRecipientType = null;
            });
          },
        ),
        const Gap(16.0),
        Text(
          'Payout method',
          style: context.font.bodyLarge?.copyWith(
            color: context.colour.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(12),
        RecipientTypeSelector(
          selectedJurisdiction: _selectedJurisdiction,
          selectedType: _selectedRecipientType,
          onTypeSelected: (newType) {
            setState(() {
              _selectedRecipientType = newType;
            });
          },
        ),
        const Gap(16.0),
        switch (_selectedRecipientType) {
          // CANADA types
          RecipientType.interacEmailCad => const Text('Interac Email Form'),
          RecipientType.billPaymentCad => const Text('Bill Payment Form'),
          RecipientType.bankTransferCad => const Text('Bank Transfer Form'),
          // EUROPE types
          RecipientType.sepaEur => const Text('SEPA Form'),
          // MEXICO types
          RecipientType.speiClabeMxn => const Text('SPEI CLABE Form'),
          RecipientType.speiSmsMxn => const Text('SPEI SMS Form'),
          RecipientType.speiCardMxn => const Text('SPEI Card Form'),
          // COSTA RICA types
          RecipientType.sinpeIbanUsd => const Text('SINPE IBAN USD Form'),
          RecipientType.sinpeIbanCrc => const Text('SINPE IBAN CRC Form'),
          RecipientType.sinpeMovilCrc => const Text('SINPE Móvil CRC Form'),
          // ARGENTINA types
          RecipientType.cbuCvuArgentina => const Text('CBU/CVU Argentina Form'),
          // TODO: Handle this case.
          null => const SizedBox.shrink(),
        },
      ],
    );
  }
}
