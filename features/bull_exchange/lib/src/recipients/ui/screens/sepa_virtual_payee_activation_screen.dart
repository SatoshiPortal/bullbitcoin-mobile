import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/presentation/exchange_failure_l10n.dart';
import 'package:bull_exchange/src/recipients/presentation/sepa_virtual_payee_activation_cubit.dart';
import 'package:bull_exchange/src/recipients/recipients_scope.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Activates a SEPA recipient for Confidential SEPA. [onActivated] runs when
/// the recipient becomes active, or when the user continues with a recipient
/// that was already active. [onUseRegularSepa] lets the user pay the same
/// recipient through regular SEPA instead.
class SepaVirtualPayeeActivationScreen extends StatelessWidget {
  const SepaVirtualPayeeActivationScreen({
    super.key,
    required this.recipientId,
    required this.onActivated,
    required this.onUseRegularSepa,
    this.onReturnHome,
  });

  final String recipientId;
  final VoidCallback onActivated;
  final VoidCallback onUseRegularSepa;

  /// Leaves the flow for the app home while activation continues in the
  /// background. When null, the button is not shown.
  final VoidCallback? onReturnHome;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          RecipientsScope.read(context).createActivationCubit(recipientId)
            ..start(),
      child: SepaVirtualPayeeActivationView(
        onActivated: onActivated,
        onUseRegularSepa: onUseRegularSepa,
        onReturnHome: onReturnHome,
      ),
    );
  }
}

class SepaVirtualPayeeActivationView extends StatelessWidget {
  const SepaVirtualPayeeActivationView({
    super.key,
    required this.onActivated,
    required this.onUseRegularSepa,
    this.onReturnHome,
  });

  final VoidCallback onActivated;
  final VoidCallback onUseRegularSepa;
  final VoidCallback? onReturnHome;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final onReturnHome = this.onReturnHome;

    return BlocConsumer<
      SepaVirtualPayeeActivationCubit,
      SepaVirtualPayeeActivationState
    >(
      listenWhen: (previous, current) =>
          previous.status != null && !previous.isActive && current.isActive,
      listener: (_, _) => onActivated(),
      builder: (context, state) {
        final failure = state.failure;
        final (title, description) = switch (state.status) {
          SepaVirtualPayeeStatus.active => (
            context.loc.recipientsConfidentialSepaActivatedTitle,
            context.loc.recipientsConfidentialSepaActivatedDescription,
          ),
          SepaVirtualPayeeStatus.absent => (
            context.loc.recipientsConfidentialSepaNotActivatedTitle,
            context.loc.recipientsConfidentialSepaNotActivatedDescription,
          ),
          SepaVirtualPayeeStatus.unknown => (
            context.loc.recipientsConfidentialSepaStatusUnknownTitle,
            context.loc.recipientsConfidentialSepaStatusUnknownDescription,
          ),
          SepaVirtualPayeeStatus.pending || null => (
            context.loc.recipientsConfidentialSepaActivatingTitle,
            context.loc.recipientsConfidentialSepaActivatingDescription,
          ),
        };

        return BullScaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                BullTopBar(
                  title: context.loc.recipientsTypeConfidentialSepa,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                BullFadingLinearProgress(
                  trigger: state.isWatching && failure == null,
                ),
                Expanded(
                  child: BullScrollableColumn(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                    crossAxisAlignment: .stretch,
                    children: [
                      if (state.isActive) ...[
                        BullIcon(
                          BullIcons.checkCircle,
                          size: 48,
                          color: colors.success,
                        ),
                        const Gap(16),
                      ],
                      BullText(
                        title,
                        style: context.bullType.subtitle.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                        color: colors.text,
                        textAlign: .center,
                      ),
                      const Gap(12),
                      BullText(
                        description,
                        style: context.bullType.body,
                        color: colors.textMuted,
                        textAlign: .center,
                      ),
                      if (failure != null) ...[
                        const Gap(16),
                        BullText(
                          failure.toTranslated(context),
                          style: context.bullType.body,
                          color: colors.error,
                          textAlign: .center,
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Column(
                    crossAxisAlignment: .stretch,
                    children: [
                      if (state.isActive)
                        BullButton.primary(
                          label: context.loc.recipientsContinue,
                          onPressed: onActivated,
                        )
                      else ...[
                        if (failure != null) ...[
                          BullButton.primary(
                            label: context.loc.retry,
                            onPressed: () => context
                                .read<SepaVirtualPayeeActivationCubit>()
                                .retry(),
                          ),
                          const Gap(12),
                        ],
                        BullButton.secondary(
                          label: context
                              .loc
                              .recipientsConfidentialSepaUseRegularSepa,
                          onPressed: onUseRegularSepa,
                        ),
                        if (onReturnHome != null) ...[
                          const Gap(12),
                          BullButton.secondary(
                            label: context.loc.recipientsReturnHome,
                            onPressed: onReturnHome,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
