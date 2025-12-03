import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/jurisdiction_dropdown.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/bank_account_cop_form.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/bank_transfer_cad_form.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/bill_payment_cad_form.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/cbu_cvu_argentina_form.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/interac_email_cad_form.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/nequi_cop_form.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/sepa_eur_form.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/sinpe_iban_form.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/sinpe_movil_crc_form.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/spei_card_mxn_form.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/spei_clabe_mxn_form.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/spei_sms_mxn_form.dart';
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
    return ScrollableColumn(
      // Padding is already handled by the parent widget
      padding: EdgeInsets.zero,
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
            color: context.appColors.secondary,
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
          RecipientType.interacEmailCad => const InteracEmailCadForm(),
          RecipientType.billPaymentCad => const BillPaymentCadForm(),
          RecipientType.bankTransferCad => const BankTransferCadForm(),
          // EUROPE types
          RecipientType.sepaEur => const SepaEurForm(),
          // MEXICO types
          RecipientType.speiClabeMxn => const SpeiClabeMxnForm(),
          RecipientType.speiSmsMxn => const SpeiSmsMxnForm(),
          RecipientType.speiCardMxn => const SpeiCardMxnForm(),
          // COSTA RICA types
          RecipientType.sinpeIbanUsd => const SinpeIbanForm(
            recipientType: RecipientType.sinpeIbanUsd,
          ),
          RecipientType.sinpeIbanCrc => const SinpeIbanForm(
            recipientType: RecipientType.sinpeIbanCrc,
          ),
          RecipientType.sinpeMovilCrc => const SinpeMovilCrcForm(),
          // ARGENTINA types
          RecipientType.cbuCvuArgentina => const CbuCvuArgentinaForm(),
          // TODO: Colombia types
          RecipientType.pseColombia => const BankAccountCopForm(),
          RecipientType.nequiColombia => const NequiCopForm(),
          null => const SizedBox.shrink(),
        },
      ],
    );
  }
}
