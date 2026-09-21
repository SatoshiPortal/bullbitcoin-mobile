import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
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
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:flutter/widgets.dart';

class RecipientForm extends StatelessWidget {
  const RecipientForm({
    required this.recipientType,
    this.recipient,
    this.hookError,
    super.key,
  });

  final RecipientType recipientType;
  final RecipientViewModel? recipient;
  final String? hookError;

  @override
  Widget build(BuildContext context) {
    return switch (recipientType) {
      RecipientType.interacEmailCad => InteracEmailCadForm(
        recipient: recipient,
        hookError: hookError,
      ),
      RecipientType.billPaymentCad => BillPaymentCadForm(
        recipient: recipient,
        hookError: hookError,
      ),
      RecipientType.bankTransferCad => BankTransferCadForm(
        recipient: recipient,
        hookError: hookError,
      ),
      RecipientType.sepaEur => SepaEurForm(
        recipient: recipient,
        hookError: hookError,
      ),
      RecipientType.speiClabeMxn => SpeiClabeMxnForm(
        recipient: recipient,
        hookError: hookError,
      ),
      RecipientType.speiSmsMxn => SpeiSmsMxnForm(
        recipient: recipient,
        hookError: hookError,
      ),
      RecipientType.speiCardMxn => SpeiCardMxnForm(
        recipient: recipient,
        hookError: hookError,
      ),
      RecipientType.sinpeIbanUsd || RecipientType.sinpeIbanCrc => SinpeIbanForm(
        recipientType: recipientType,
        recipient: recipient,
        hookError: hookError,
      ),
      RecipientType.sinpeMovilCrc => SinpeMovilCrcForm(
        recipient: recipient,
        hookError: hookError,
      ),
      RecipientType.bankAccountArgentina => BankAccountArgentinaForm(
        recipient: recipient,
        hookError: hookError,
      ),
      RecipientType.pseColombia => BankAccountCopForm(
        recipient: recipient,
        hookError: hookError,
      ),
      RecipientType.nequiColombia => NequiCopForm(
        recipient: recipient,
        hookError: hookError,
      ),
    };
  }
}
