import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_flow_step.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipients_location.dart';
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
  NewRecipientTabState createState() => NewRecipientTabState();
}

class NewRecipientTabState extends State<NewRecipientTab> {
  late String _selectedJurisdiction;
  RecipientType? _selectedRecipientType;
  bool _hasAppliedDefault = false;

  @override
  void initState() {
    super.initState();
    final blocState = context.read<RecipientsBloc>().state;

    // Check if we're in Step 2 of a step-based flow (type was already selected in Step 1)
    // This includes sell, withdraw, AND pay flows
    final isStep2OfStepBasedFlow = blocState.allowedRecipientFilters.location
            .usesStepBasedFlow &&
        blocState.currentStep == RecipientFlowStep.enterDetails &&
        blocState.selectedRecipientType != null;

    if (isStep2OfStepBasedFlow) {
      // Use the pre-selected type from Step 1
      _selectedRecipientType = blocState.selectedRecipientType;
      _selectedJurisdiction =
          blocState.selectedJurisdiction ?? _selectedRecipientType!.jurisdictionCode;
      _hasAppliedDefault = true;
    } else {
      // Initialize with the user's default jurisdiction if available
      _selectedJurisdiction =
          blocState.selectableRecipientTypes.map((t) => t.jurisdictionCode).first;

      // Apply default selected type from bloc state (e.g., for VIBAN auto-selection)
      final defaultType = blocState.allowedRecipientFilters.defaultSelectedType;
      if (defaultType != null && !_hasAppliedDefault) {
        _selectedRecipientType = defaultType;
        // Update jurisdiction to match the default type's jurisdiction
        _selectedJurisdiction = defaultType.jurisdictionCode;
        _hasAppliedDefault = true;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Also check for default type updates from bloc
    if (!_hasAppliedDefault) {
      final defaultType = context
          .read<RecipientsBloc>()
          .state
          .allowedRecipientFilters
          .defaultSelectedType;
      if (defaultType != null) {
        setState(() {
          _selectedRecipientType = defaultType;
          _selectedJurisdiction = defaultType.jurisdictionCode;
          _hasAppliedDefault = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocState = context.watch<RecipientsBloc>().state;

    // Check if we're in Step 2 of a step-based flow (type was already selected in Step 1)
    // This includes sell, withdraw, AND pay flows
    final isStep2OfStepBasedFlow = blocState.allowedRecipientFilters.location
            .usesStepBasedFlow &&
        blocState.currentStep == RecipientFlowStep.enterDetails &&
        blocState.selectedRecipientType != null;

    // If in Step 2 of step-based flow, show only the form (no type selector)
    if (isStep2OfStepBasedFlow) {
      return _buildFormOnly(blocState.selectedRecipientType!);
    }

    // Standard view: show jurisdiction dropdown + type selector + form
    return _buildFullView();
  }

  /// Builds the form-only view for Step 2 of VIBAN-eligible flows.
  /// Type was already selected in Step 1, so we show the form directly.
  Widget _buildFormOnly(RecipientType selectedType) {
    return ScrollableColumn(
      padding: EdgeInsets.zero,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show selected type as a header
        Text(
          _getTypeDisplayName(selectedType),
          style: context.font.titleMedium?.copyWith(
            color: context.appColors.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Gap(16.0),
        _buildFormForType(selectedType),
      ],
    );
  }

  /// Builds the full view with jurisdiction dropdown, type selector, and form.
  Widget _buildFullView() {
    return BlocListener<RecipientsBloc, RecipientsState>(
      listenWhen: (previous, current) =>
          previous.allowedRecipientFilters.defaultSelectedType !=
          current.allowedRecipientFilters.defaultSelectedType,
      listener: (context, state) {
        // React to async VIBAN status changes that set the default type
        final defaultType = state.allowedRecipientFilters.defaultSelectedType;
        if (defaultType != null && !_hasAppliedDefault) {
          setState(() {
            _selectedRecipientType = defaultType;
            _selectedJurisdiction = defaultType.jurisdictionCode;
            _hasAppliedDefault = true;
          });
        }
      },
      child: ScrollableColumn(
        padding: EdgeInsets.zero,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JurisdictionsDropdown(
            selectedJurisdiction: _selectedJurisdiction,
            onChanged: (newJurisdiction) {
              if (newJurisdiction == null) return;
              setState(() {
                _selectedJurisdiction = newJurisdiction;
                // Reset selected type as well since the possible types
                // depend on the selected jurisdiction
                _selectedRecipientType = null;
              });
            },
          ),
          const Gap(16.0),
          Text(
            context.loc.payoutMethod,
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
          if (_selectedRecipientType != null)
            _buildFormForType(_selectedRecipientType!),
        ],
      ),
    );
  }

  String _getTypeDisplayName(RecipientType type) {
    return switch (type) {
      RecipientType.frPayee => context.loc.confidentialSepaTitle,
      RecipientType.cjPayee => context.loc.regularSepa,
      RecipientType.sepaEur => 'SEPA Transfer',
      RecipientType.interacEmailCad => 'Interac e-Transfer',
      RecipientType.billPaymentCad => 'Bill Payment',
      RecipientType.bankTransferCad => 'Bank Transfer',
      RecipientType.speiClabeMxn => 'SPEI CLABE',
      RecipientType.speiSmsMxn => 'SPEI SMS',
      RecipientType.speiCardMxn => 'SPEI Card',
      RecipientType.sinpeIbanUsd => 'SINPE IBAN (USD)',
      RecipientType.sinpeIbanCrc => 'SINPE IBAN (CRC)',
      RecipientType.sinpeMovilCrc => 'SINPE Móvil',
      RecipientType.cbuCvuArgentina => 'CBU/CVU Argentina',
      RecipientType.pseColombia => 'Bank Account COP',
      RecipientType.nequiColombia => 'Nequi',
      RecipientType.frVirtualAccount => 'Virtual IBAN',
    };
  }

  Widget _buildFormForType(RecipientType type) {
    return switch (type) {
      // CANADA types
      RecipientType.interacEmailCad => const InteracEmailCadForm(),
      RecipientType.billPaymentCad => const BillPaymentCadForm(),
      RecipientType.bankTransferCad => const BankTransferCadForm(),
      // EUROPE types
      RecipientType.sepaEur => const SepaEurForm(),
      // Virtual IBAN payee types - use SEPA form for entering recipient details
      RecipientType.frPayee || RecipientType.cjPayee => const SepaEurForm(),
      // frVirtualAccount is system-managed, not user-created
      RecipientType.frVirtualAccount => const SizedBox.shrink(),
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
      // Colombia types
      RecipientType.pseColombia => const BankAccountCopForm(),
      RecipientType.nequiColombia => const NequiCopForm(),
    };
  }
}
