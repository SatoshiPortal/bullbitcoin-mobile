import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/recipients/presentation/virtual_iban_onboarding_cubit.dart';
import 'package:bull_exchange/src/recipients/ui/screens/virtual_iban_onboarding_screen.dart';
import 'package:bull_exchange/src/recipients/recipients_scope.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Deposit details of the user's virtual IBAN, after creating it when needed.
/// [onUseRegularSepa] lets the user fund through regular SEPA instead, and
/// [onDone] leaves the funding flow, [onBack] goes back in it.
class VirtualIbanFundingScreen extends StatelessWidget {
  const VirtualIbanFundingScreen({
    super.key,
    required this.onUseRegularSepa,
    required this.onDone,
    required this.onBack,
  });

  final VoidCallback onUseRegularSepa;
  final VoidCallback onDone;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          RecipientsScope.read(context).createVirtualIbanCubit()..start(),
      child: VirtualIbanFundingView(
        onUseRegularSepa: onUseRegularSepa,
        onDone: onDone,
        onBack: onBack,
      ),
    );
  }
}

class VirtualIbanFundingView extends StatefulWidget {
  const VirtualIbanFundingView({
    super.key,
    required this.onUseRegularSepa,
    required this.onDone,
    required this.onBack,
  });

  final VoidCallback onUseRegularSepa;
  final VoidCallback onDone;
  final VoidCallback onBack;

  @override
  State<VirtualIbanFundingView> createState() => _VirtualIbanFundingViewState();
}

class _VirtualIbanFundingViewState extends State<VirtualIbanFundingView> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<VirtualIbanOnboardingCubit, VirtualIbanOnboardingState>(
      // An account that was already active needs no onboarding.
      listenWhen: (previous, current) =>
          previous.step == VirtualIbanOnboardingStep.loading &&
          current.step == VirtualIbanOnboardingStep.active,
      listener: (_, _) => setState(() => _showDetails = true),
      child:
          BlocBuilder<VirtualIbanOnboardingCubit, VirtualIbanOnboardingState>(
            buildWhen: (previous, current) =>
                previous.virtualIban != current.virtualIban ||
                previous.accountOwnerName != current.accountOwnerName,
            builder: (context, state) {
              final virtualIban = state.virtualIban;
              if (_showDetails && virtualIban != null) {
                return _VirtualIbanDetails(
                  virtualIban: virtualIban,
                  accountOwnerName: state.accountOwnerName ?? '',
                  onDone: widget.onDone,
                  onBack: widget.onBack,
                );
              }
              return VirtualIbanOnboardingView(
                purpose: VirtualIbanOnboardingPurpose.funding,
                onActivated: () => setState(() => _showDetails = true),
                onUseRegularSepa: widget.onUseRegularSepa,
                onBack: widget.onBack,
              );
            },
          ),
    );
  }
}

class _VirtualIbanDetails extends StatelessWidget {
  const _VirtualIbanDetails({
    required this.virtualIban,
    required this.accountOwnerName,
    required this.onDone,
    required this.onBack,
  });

  final ActiveVirtualIban virtualIban;
  final String accountOwnerName;
  final VoidCallback onDone;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final copied = context.loc.recipientsVirtualIbanCopied;

    return BullScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            BullTopBar(
              title: context.loc.recipientsTypeConfidentialSepa,
              onBack: onBack,
            ),
            Expanded(
              child: BullScrollableColumn(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                crossAxisAlignment: .stretch,
                children: [
                  BullText(
                    context.loc.recipientsVirtualIbanDetailsDescription,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    color: colors.text,
                  ),
                  const Gap(16),
                  BullInfoCard(
                    title: context.loc.recipientsVirtualIbanNameWarningTitle,
                    description:
                        context.loc.recipientsVirtualIbanNameWarningDescription,
                    bgColor: colors.warningContainer,
                    tagColor: colors.warning,
                  ),
                  const Gap(24),
                  BullDetailsTable(
                    items: [
                      BullDetailsTableItem(
                        label: context.loc.recipientsVirtualIbanIbanLabel,
                        displayValue: virtualIban.iban,
                        copyValue: virtualIban.iban,
                        copiedMessage: copied,
                      ),
                      BullDetailsTableItem(
                        label: context.loc.recipientsVirtualIbanRecipientName,
                        displayValue: accountOwnerName,
                        copyValue: accountOwnerName,
                        copiedMessage: copied,
                      ),
                      BullDetailsTableItem(
                        label: context.loc.recipientsVirtualIbanBankAddress,
                        displayValue: virtualIban.bankAddress,
                        copyValue: virtualIban.bankAddress,
                        copiedMessage: copied,
                      ),
                      if (virtualIban.ibanCountry case final country?)
                        BullDetailsTableItem(
                          label: context.loc.recipientsVirtualIbanCountry,
                          displayValue: country,
                        ),
                      BullDetailsTableItem(
                        label: context.loc.recipientsVirtualIbanBic,
                        displayValue: virtualIban.bicCode,
                        copyValue: virtualIban.bicCode,
                        copiedMessage: copied,
                      ),
                    ],
                  ),
                  const Gap(12),
                  BullText(
                    context.loc.recipientsVirtualIbanBankAddressHelp,
                    style: context.bullType.label.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                    color: colors.textMuted,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: BullButton.primary(
                label: context.loc.recipientsVirtualIbanDone,
                onPressed: onDone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
