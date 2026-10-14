import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/get_account_owner_name_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_virtual_iban_usecase.dart';
import 'package:bb_mobile/features/recipients/presentation/recipients_failure_l10n.dart';
import 'package:bb_mobile/features/recipients/presentation/virtual_iban_onboarding_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Creates the user's virtual IBAN, which Confidential SEPA needs.
/// [onActivated] continues once it is active. [onUseRegularSepa] lets the
/// user continue with regular SEPA while it is still being created.
class VirtualIbanOnboardingScreen extends StatelessWidget {
  const VirtualIbanOnboardingScreen({
    super.key,
    required this.onActivated,
    required this.onUseRegularSepa,
  });

  final VoidCallback onActivated;
  final VoidCallback onUseRegularSepa;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => VirtualIbanOnboardingCubit(
        watchVirtualIbanUsecase: locator<WatchVirtualIbanUsecase>(),
        getAccountOwnerNameUsecase: locator<GetAccountOwnerNameUsecase>(),
      )..start(),
      child: VirtualIbanOnboardingView(
        onActivated: onActivated,
        onUseRegularSepa: onUseRegularSepa,
      ),
    );
  }
}

class VirtualIbanOnboardingView extends StatelessWidget {
  const VirtualIbanOnboardingView({
    super.key,
    required this.onActivated,
    required this.onUseRegularSepa,
  });

  final VoidCallback onActivated;
  final VoidCallback onUseRegularSepa;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<VirtualIbanOnboardingCubit>().state;
    final isWorking =
        state.failure == null &&
        (state.step == VirtualIbanOnboardingStep.loading ||
            state.step == VirtualIbanOnboardingStep.activating ||
            state.isCreating);

    return BullScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            BullTopBar(
              title: context.loc.recipientsTypeConfidentialSepa,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            BullFadingLinearProgress(trigger: isWorking),
            Expanded(
              child: switch (state.step) {
                VirtualIbanOnboardingStep.loading => _LoadingStep(state: state),
                VirtualIbanOnboardingStep.intro => _IntroStep(state: state),
                VirtualIbanOnboardingStep.activating => _ActivatingStep(
                  state: state,
                  onUseRegularSepa: onUseRegularSepa,
                ),
                VirtualIbanOnboardingStep.active => _ActiveStep(
                  onActivated: onActivated,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingStep extends StatelessWidget {
  const _LoadingStep({required this.state});

  final VirtualIbanOnboardingState state;

  @override
  Widget build(BuildContext context) {
    final failure = state.failure;
    if (failure == null) return const SizedBox.shrink();
    return _StatusLayout(
      title: failure.toTranslated(context),
      buttons: [_RetryButton()],
    );
  }
}

class _IntroStep extends StatefulWidget {
  const _IntroStep({required this.state});

  final VirtualIbanOnboardingState state;

  @override
  State<_IntroStep> createState() => _IntroStepState();
}

class _IntroStepState extends State<_IntroStep> {
  bool _nameConfirmed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final state = widget.state;
    final failure = state.failure;

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Expanded(
          child: BullScrollableColumn(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            crossAxisAlignment: .stretch,
            children: [
              Row(
                children: [
                  Flexible(
                    child: BullText(
                      context.loc.recipientsVirtualIbanIntroTitle,
                      style: context.bullText.headlineSmall,
                      color: colors.text,
                    ),
                  ),
                  const Gap(8),
                  BullBadge(
                    label: context.loc.recipientsVirtualIbanNewBadge,
                    background: colors.tertiaryContainer,
                    foreground: colors.onTertiary,
                    uppercase: true,
                  ),
                ],
              ),
              const Gap(12),
              BullText(
                context.loc.recipientsVirtualIbanIntroDescription,
                style: context.bullText.bodyMedium,
                color: colors.text,
              ),
              const Gap(16),
              _Bullet(context.loc.recipientsVirtualIbanIntroSelfTransfer),
              _Bullet(context.loc.recipientsVirtualIbanIntroNoTransferCode),
              const Gap(16),
              BullInfoCard(
                title: context.loc.recipientsVirtualIbanNameWarningTitle,
                description:
                    context.loc.recipientsVirtualIbanNameWarningDescription,
                bgColor: colors.warningContainer,
                tagColor: colors.warning,
              ),
              const Gap(20),
              BullText(
                context.loc.recipientsVirtualIbanAccountOwnerName,
                style: context.bullText.bodyLarge,
                color: colors.text,
              ),
              const Gap(8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(8),
                  color: colors.surface,
                ),
                child: BullText(
                  state.accountOwnerName ?? '',
                  style: context.bullText.bodyLarge,
                  color: colors.text,
                ),
              ),
              const Gap(16),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _nameConfirmed = !_nameConfirmed),
                child: Row(
                  children: [
                    BullCheckbox(
                      checked: _nameConfirmed,
                      onChanged: (value) =>
                          setState(() => _nameConfirmed = value),
                    ),
                    const Gap(12),
                    Expanded(
                      child: BullText(
                        context.loc.recipientsVirtualIbanNameConfirmation,
                        style: context.bullText.bodyMedium,
                        color: colors.text,
                      ),
                    ),
                  ],
                ),
              ),
              if (failure != null) ...[
                const Gap(16),
                BullText(
                  failure.toTranslated(context),
                  style: context.bullText.bodyMedium,
                  color: colors.error,
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: BullButton.big(
            label: context.loc.recipientsVirtualIbanActivate,
            disabled: !_nameConfirmed || state.isCreating,
            onPressed: () =>
                context.read<VirtualIbanOnboardingCubit>().activate(),
            bgColor: colors.primary,
            textColor: colors.onPrimary,
          ),
        ),
      ],
    );
  }
}

class _ActivatingStep extends StatelessWidget {
  const _ActivatingStep({required this.state, required this.onUseRegularSepa});

  final VirtualIbanOnboardingState state;
  final VoidCallback onUseRegularSepa;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final failure = state.failure;
    return _StatusLayout(
      icon: BullIcon(BullIcons.schedule, size: 48, color: colors.text),
      title: context.loc.recipientsVirtualIbanActivatingTitle,
      description: context.loc.recipientsVirtualIbanActivatingDescription,
      error: failure?.toTranslated(context),
      buttons: [
        if (failure != null) ...[_RetryButton(), const Gap(12)],
        BullButton.big(
          label: context.loc.recipientsConfidentialSepaUseRegularSepa,
          onPressed: onUseRegularSepa,
          bgColor: colors.surface,
          textColor: colors.text,
          outlined: true,
          borderColor: colors.outline,
        ),
      ],
    );
  }
}

class _ActiveStep extends StatelessWidget {
  const _ActiveStep({required this.onActivated});

  final VoidCallback onActivated;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return _StatusLayout(
      icon: BullIcon(BullIcons.checkCircle, size: 48, color: colors.success),
      title: context.loc.recipientsVirtualIbanActivatedTitle,
      description: context.loc.recipientsVirtualIbanActivatedDescription,
      buttons: [
        BullButton.big(
          label: context.loc.recipientsContinue,
          onPressed: onActivated,
          bgColor: colors.primary,
          textColor: colors.onPrimary,
        ),
      ],
    );
  }
}

class _StatusLayout extends StatelessWidget {
  const _StatusLayout({
    this.icon,
    required this.title,
    this.description,
    this.error,
    required this.buttons,
  });

  final Widget? icon;
  final String title;
  final String? description;
  final String? error;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Expanded(
          child: BullScrollableColumn(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            crossAxisAlignment: .stretch,
            children: [
              if (icon != null) ...[icon!, const Gap(16)],
              BullText(
                title,
                style: context.bullText.headlineSmall,
                color: colors.text,
                textAlign: .center,
              ),
              if (description != null) ...[
                const Gap(12),
                BullText(
                  description!,
                  style: context.bullText.bodyMedium,
                  color: colors.textMuted,
                  textAlign: .center,
                ),
              ],
              if (error != null) ...[
                const Gap(16),
                BullText(
                  error!,
                  style: context.bullText.bodyMedium,
                  color: colors.error,
                  textAlign: .center,
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(crossAxisAlignment: .stretch, children: buttons),
        ),
      ],
    );
  }
}

class _RetryButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return BullButton.big(
      label: context.loc.retry,
      onPressed: () => context.read<VirtualIbanOnboardingCubit>().start(),
      bgColor: colors.primary,
      textColor: colors.onPrimary,
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          BullText('•', style: context.bullText.bodyMedium, color: colors.text),
          const Gap(8),
          Expanded(
            child: BullText(
              text,
              style: context.bullText.bodyMedium,
              color: colors.text,
            ),
          ),
        ],
      ),
    );
  }
}
