import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipients_location.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/jurisdiction_dropdown.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_type_text.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/virtual_iban/presentation/virtual_iban_bloc.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

/// Step 1 of the recipient creation flow for VIBAN-eligible locations (sell/withdraw).
///
/// Displays:
/// - Jurisdiction dropdown (locked for sell/withdraw flows)
/// - Radio button list of recipient types
/// - For EUR with frPayee: "Activate Confidential SEPA" + NEW tag when VIBAN not active
/// - Continue button to proceed to Step 2 or VIBAN activation
class RecipientTypeSelectionStep extends StatefulWidget {
  const RecipientTypeSelectionStep({super.key});

  @override
  State<RecipientTypeSelectionStep> createState() =>
      _RecipientTypeSelectionStepState();
}

class _RecipientTypeSelectionStepState
    extends State<RecipientTypeSelectionStep> {
  late String _selectedJurisdiction;
  RecipientType? _selectedType;

  @override
  void initState() {
    super.initState();
    final blocState = context.read<RecipientsBloc>().state;

    // Initialize jurisdiction - for sell/withdraw, use user's default or first available
    final availableJurisdictions = blocState.availableJurisdictions;
    _selectedJurisdiction =
        availableJurisdictions.isNotEmpty ? availableJurisdictions.first : 'EU';

    // Check if VIBAN is active and auto-select frPayee for EU
    final isVibanActive = locator<VirtualIbanBloc>().state.isActive;
    if (_selectedJurisdiction == 'EU' && isVibanActive) {
      _selectedType = RecipientType.frPayee;
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = context.select(
      (RecipientsBloc bloc) => bloc.state.allowedRecipientFilters.location,
    );

    // Lock jurisdiction for withdraw flow
    final isJurisdictionLocked = location == RecipientsLocation.withdrawView;

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.selectRecipient,
          onBack: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Jurisdiction dropdown
              Text(
                context.loc.selectCountry,
                style: context.font.bodyLarge?.copyWith(
                  color: context.appColors.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Gap(8),
              IgnorePointer(
                ignoring: isJurisdictionLocked,
                child: Opacity(
                  opacity: isJurisdictionLocked ? 0.6 : 1.0,
                  child: JurisdictionsDropdown(
                    selectedJurisdiction: _selectedJurisdiction,
                    onChanged: (newJurisdiction) {
                      if (newJurisdiction == null) return;
                      setState(() {
                        _selectedJurisdiction = newJurisdiction;
                        _selectedType = null; // Reset type on jurisdiction change
                      });
                    },
                  ),
                ),
              ),
              const Gap(24),

              // Recipient type label
              Text(
                context.loc.payoutMethod,
                style: context.font.bodyLarge?.copyWith(
                  color: context.appColors.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Gap(12),

              // Recipient type radio buttons
              Expanded(
                child: _RecipientTypeRadioList(
                  selectedJurisdiction: _selectedJurisdiction,
                  selectedType: _selectedType,
                  onTypeSelected: (type) {
                    setState(() {
                      _selectedType = type;
                    });
                  },
                ),
              ),

              // Continue button
              const Gap(16),
              BBButton.big(
                label: context.loc.continueButton,
                disabled: _selectedType == null,
                onPressed: _onContinuePressed,
                bgColor: context.appColors.primary,
                textColor: context.appColors.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onContinuePressed() {
    final selectedType = _selectedType;
    if (selectedType == null) return;

    // Dispatch the next step event with the selected type
    context.read<RecipientsBloc>().add(
          RecipientsEvent.nextStepPressed(selectedType: selectedType),
        );
  }
}

/// Radio button list for selecting recipient type.
///
/// Shows "Activate Confidential SEPA" with NEW badge for frPayee when VIBAN is not active.
class _RecipientTypeRadioList extends StatelessWidget {
  const _RecipientTypeRadioList({
    required this.selectedJurisdiction,
    required this.selectedType,
    required this.onTypeSelected,
  });

  final String selectedJurisdiction;
  final RecipientType? selectedType;
  final Function(RecipientType) onTypeSelected;

  @override
  Widget build(BuildContext context) {
    // Get available types for the selected jurisdiction
    final availableTypes = context.select(
      (RecipientsBloc bloc) =>
          bloc.state.recipientTypesForJurisdiction(selectedJurisdiction),
    );

    // Get location to determine if this is a VIBAN-eligible flow
    final location = context.select(
      (RecipientsBloc bloc) => bloc.state.allowedRecipientFilters.location,
    );
    final isVibanEligible = location.isVirtualIbanEligible;

    // Check VIBAN status
    final isVibanActive = locator<VirtualIbanBloc>().state.isActive;

    // Filter out system types that shouldn't be shown to users
    // frVirtualAccount is system-created, users select frPayee for Confidential SEPA
    var selectableTypes = availableTypes
        .where((type) => type != RecipientType.frVirtualAccount)
        .toList();

    // frPayee (Confidential SEPA) is only available for "to your account" flows
    // (sell/withdraw), NOT for pay flow (third-party payments)
    if (!isVibanEligible) {
      selectableTypes = selectableTypes
          .where((type) => type != RecipientType.frPayee)
          .toList();
    }

    // For EUR, show frPayee as "Confidential SEPA" option
    // and cjPayee as "Regular SEPA" option
    // Hide sepaEur if frPayee or cjPayee are available
    final showConfidentialSepa =
        selectableTypes.contains(RecipientType.frPayee);
    final filteredTypes = selectableTypes.where((type) {
      // Hide sepaEur if we have frPayee/cjPayee options
      if (type == RecipientType.sepaEur && showConfidentialSepa) {
        return false;
      }
      // Always show frPayee (Confidential SEPA) and cjPayee (Regular SEPA)
      return true;
    }).toList();

    return SingleChildScrollView(
      child: Column(
        children: filteredTypes.map((type) {
          final isSelected = selectedType == type;
          final isConfidentialSepa = type == RecipientType.frPayee;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RecipientTypeRadioTile(
              type: type,
              isSelected: isSelected,
              isConfidentialSepa: isConfidentialSepa,
              isVibanActive: isVibanActive,
              onTap: () => onTypeSelected(type),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Individual radio tile for a recipient type.
class _RecipientTypeRadioTile extends StatelessWidget {
  const _RecipientTypeRadioTile({
    required this.type,
    required this.isSelected,
    required this.isConfidentialSepa,
    required this.isVibanActive,
    required this.onTap,
  });

  final RecipientType type;
  final bool isSelected;
  final bool isConfidentialSepa;
  final bool isVibanActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? context.appColors.primary
                : context.appColors.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? context.appColors.primary.withValues(alpha: 0.08)
              : null,
        ),
        child: Row(
          children: [
            // Radio indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? context.appColors.primary
                      : context.appColors.outline,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.appColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const Gap(16),

            // Label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: _buildTypeLabel(context),
                      ),
                      // NEW badge for Confidential SEPA when not yet activated
                      if (isConfidentialSepa && !isVibanActive) ...[
                        const Gap(8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.appColors.tertiaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            context.loc.newBadge.toUpperCase(),
                            style: context.font.labelSmall?.copyWith(
                              color: context.appColors.secondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Description for Confidential SEPA
                  if (isConfidentialSepa) ...[
                    const Gap(4),
                    Text(
                      context.loc.confidentialSepaShortDesc,
                      style: context.font.bodySmall?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeLabel(BuildContext context) {
    // Special label for Confidential SEPA based on activation status
    if (isConfidentialSepa) {
      final labelText = isVibanActive
          ? context.loc.confidentialSepaTitle
          : context.loc.activateConfidentialSepa;
      return Text(
        labelText,
        style: context.font.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      );
    }

    // Special label for regular SEPA (cjPayee)
    if (type == RecipientType.cjPayee) {
      return Text(
        context.loc.regularSepa,
        style: context.font.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      );
    }

    // Default label from RecipientTypeText
    return RecipientTypeText(
      recipientType: type,
      style: context.font.titleMedium?.copyWith(
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
