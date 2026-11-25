import 'package:bull_exchange/src/exchange_l10n.dart';

import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/jurisdiction_dropdown.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/new_recipient_forms/bank_account_cop_form.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/new_recipient_forms/bank_transfer_cad_form.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/new_recipient_forms/bill_payment_cad_form.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/new_recipient_forms/cbu_cvu_argentina_form.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/new_recipient_forms/interac_email_cad_form.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/new_recipient_forms/nequi_cop_form.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/new_recipient_forms/sepa_eur_form.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/new_recipient_forms/sinpe_iban_form.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/new_recipient_forms/sinpe_movil_crc_form.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/new_recipient_forms/spei_card_mxn_form.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/new_recipient_forms/spei_clabe_mxn_form.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/new_recipient_forms/spei_sms_mxn_form.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/recipient_type_selector.dart';
import 'package:bull_exchange/src/recipients/presentation/recipients_bloc.dart';
import 'package:bull_exchange/src/recipients/ui/screens/virtual_iban_onboarding_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullScrollableColumn, Gap, BullTypographyX;

class NewRecipientTab extends StatefulWidget {
  const NewRecipientTab({this.hookError, this.fixedRecipientType, super.key});

  final String? hookError;
  final RecipientType? fixedRecipientType;

  @override
  NewRecipientTabState createState() => NewRecipientTabState();
}

class NewRecipientTabState extends State<NewRecipientTab> {
  Jurisdiction? _selectedJurisdiction;
  RecipientType? _selectedRecipientType;
  StreamSubscription<RecipientsState>? stateSubscription;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<RecipientsBloc>();
    _selectedJurisdiction = bloc.state.selectedJurisdiction;
    if (_selectedJurisdiction == null) {
      // Listen for state updates in case the tab is opened before
      // the preferred jurisdiction is loaded
      stateSubscription = bloc.stream.listen((state) {
        if (state.selectedJurisdiction != null &&
            _selectedJurisdiction == null) {
          setState(() {
            _selectedJurisdiction = state.selectedJurisdiction;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    stateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _onTypeSelected(RecipientType type) async {
    final bloc = context.read<RecipientsBloc>();
    if (type != _selectedRecipientType) {
      bloc.add(const RecipientsEvent.newRecipientFormChanged());
    }
    setState(() => _selectedRecipientType = type);
    if (type != RecipientType.confidentialSepaEur ||
        bloc.state.confidentialSepaAvailability !=
            ConfidentialSepaAvailability.needsVirtualIban) {
      return;
    }

    final next = await VirtualIbanOnboardingScreen.showForWithdraw(context);
    if (!mounted) return;
    if (next == RecipientType.confidentialSepaEur) {
      bloc.add(const RecipientsEvent.virtualIbanActivated());
    }
    setState(() => _selectedRecipientType = next);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RecipientsBloc>().state;
    final selectedType = widget.fixedRecipientType ?? _selectedRecipientType;
    if (widget.fixedRecipientType != null &&
        (!state.selectableRecipientTypes.contains(selectedType) ||
            (selectedType == RecipientType.confidentialSepaEur &&
                state.failedToLoadConfidentialSepaAvailability != null))) {
      return const SizedBox.shrink();
    }
    return BullScrollableColumn(
      // Padding is already handled by the parent widget
      padding: EdgeInsets.zero,
      crossAxisAlignment: .start,
      children: [
        if (widget.fixedRecipientType == null) ...[
          JurisdictionsDropdown(
            selectedJurisdiction: _selectedJurisdiction,
            onChanged: (newJurisdiction) {
              if (newJurisdiction == null) return;
              if (newJurisdiction != _selectedJurisdiction) {
                context.read<RecipientsBloc>().add(
                  const RecipientsEvent.newRecipientFormChanged(),
                );
              }
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
            context.loc.recipientsPayoutMethod,
            style: context.bullType.body.copyWith(
              color: context.appColors.secondary,
              fontWeight: .w500,
            ),
          ),
          const Gap(12),
          RecipientTypeSelector(
            selectedJurisdiction: _selectedJurisdiction,
            selectedType: _selectedRecipientType,
            onTypeSelected: _onTypeSelected,
          ),
        ],
        if (selectedType == RecipientType.confidentialSepaEur) ...[
          const Gap(8),
          Text(
            context.loc.recipientsTypeConfidentialSepaDescription,
            style: context.bullType.body,
          ),
        ],
        const Gap(16.0),
        switch (selectedType?.rail) {
          InteracEmailRail() => InteracEmailCadForm(
            hookError: widget.hookError,
          ),
          BillPaymentRail() => BillPaymentCadForm(hookError: widget.hookError),
          BankTransferCadRail() => BankTransferCadForm(
            hookError: widget.hookError,
          ),
          SepaRail() => SepaEurForm(hookError: widget.hookError),
          ConfidentialSepaRail() => SepaEurForm(
            hookError: widget.hookError,
            isConfidential: true,
          ),
          SpeiClabeRail() => SpeiClabeMxnForm(hookError: widget.hookError),
          SpeiSmsRail() => SpeiSmsMxnForm(hookError: widget.hookError),
          SpeiCardRail() => SpeiCardMxnForm(hookError: widget.hookError),
          SinpeIbanUsdRail() => SinpeIbanForm(
            recipientType: RecipientType.sinpeIbanUsd,
            hookError: widget.hookError,
          ),
          SinpeIbanCrcRail() => SinpeIbanForm(
            recipientType: RecipientType.sinpeIbanCrc,
            hookError: widget.hookError,
          ),
          SinpeMovilRail() => SinpeMovilCrcForm(hookError: widget.hookError),
          ArsBankTransferRail() => BankAccountArgentinaForm(
            hookError: widget.hookError,
          ),
          PseRail() => BankAccountCopForm(hookError: widget.hookError),
          NequiRail() => NequiCopForm(hookError: widget.hookError),
          null => const SizedBox.shrink(),
        },
      ],
    );
  }
}
