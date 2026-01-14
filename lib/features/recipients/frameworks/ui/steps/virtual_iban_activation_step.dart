import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipients_location.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/virtual_iban/presentation/virtual_iban_bloc.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

/// Widget that handles Virtual IBAN activation within the recipients flow.
///
/// This widget is shown when a user selects frPayee recipient type but
/// doesn't have an active Virtual IBAN yet. It provides:
/// - VIBAN activation intro and creation flow
/// - Pending/activation status display
/// - "Use Regular SEPA Instead" fallback option
/// - Back navigation to recipient type selection
///
/// Uses the singleton VirtualIbanBloc and triggers a refresh when shown
/// to ensure fresh state.
class VirtualIbanActivationStep extends StatefulWidget {
  const VirtualIbanActivationStep({super.key});

  @override
  State<VirtualIbanActivationStep> createState() =>
      _VirtualIbanActivationStepState();
}

class _VirtualIbanActivationStepState extends State<VirtualIbanActivationStep> {
  @override
  void initState() {
    super.initState();
    // Trigger a refresh to ensure we have the latest VIBAN state
    // This is needed because the singleton bloc might have been started
    // earlier with stale or error state
    locator<VirtualIbanBloc>().add(const VirtualIbanEvent.started());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: locator<VirtualIbanBloc>(),
      child: const _VirtualIbanActivationContent(),
    );
  }
}

class _VirtualIbanActivationContent extends StatelessWidget {
  const _VirtualIbanActivationContent();

  @override
  Widget build(BuildContext context) {
    return BlocListener<VirtualIbanBloc, VirtualIbanState>(
      listenWhen: (previous, current) {
        // Listen for activation completion
        final wasNotActive = !previous.isActive;
        final isNowActive = current.isActive;
        return wasNotActive && isNowActive;
      },
      listener: (context, state) {
        // VIBAN is now active - notify RecipientsBloc to advance
        context.read<RecipientsBloc>().add(
              const RecipientsEvent.virtualIbanActivated(),
            );
      },
      child: BlocBuilder<VirtualIbanBloc, VirtualIbanState>(
        builder: (context, state) {
          return state.when(
            initial: () => const _LoadingView(),
            loading: () => const _LoadingView(),
            notSubmitted: (
              userSummary,
              nameConfirmed,
              isCreating,
              error,
            ) =>
                _IntroView(
              userFullName:
                  '${userSummary.profile.firstName} ${userSummary.profile.lastName}'
                      .trim(),
              nameConfirmed: nameConfirmed,
              isCreating: isCreating,
              error: error,
            ),
            pending: (recipient, userSummary, isPolling) => const _PendingView(),
            active: (recipient, userSummary) => const _ActivatedView(),
            error: (exception) => _ErrorView(exception: exception),
          );
        },
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: '',
          bullLogo: true,
          onBack: () => _handleBack(context),
        ),
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _IntroView extends StatelessWidget {
  const _IntroView({
    required this.userFullName,
    required this.nameConfirmed,
    required this.isCreating,
    this.error,
  });

  final String userFullName;
  final bool nameConfirmed;
  final bool isCreating;
  final Exception? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: '',
          bullLogo: true,
          onBack: () => _handleBack(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Gap(16.0),
                    // Title with icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: context.appColors.surfaceContainer,
                          child: Icon(
                            Icons.shield_outlined,
                            size: 32,
                            color: context.appColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const Gap(16.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        BBText(
                          context.loc.confidentialSepaTitle,
                          style: theme.textTheme.displaySmall,
                        ),
                        const Gap(8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.appColors.tertiaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: BBText(
                            context.loc.newBadge,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: context.appColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(8.0),
                    BBText(
                      context.loc.confidentialSepaDescription,
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const Gap(24.0),

                    // Key features card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BBText(
                              context.loc.confidentialSepaFeaturesTitle,
                              style: theme.textTheme.headlineSmall,
                            ),
                            const Gap(12.0),
                            _buildBulletPoint(
                              context,
                              context.loc.confidentialSepaBullet1,
                            ),
                            _buildBulletPoint(
                              context,
                              context.loc.confidentialSepaBullet2,
                            ),
                            _buildBulletPoint(
                              context,
                              context.loc.confidentialSepaBullet3,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Gap(24.0),

                    // Warning card
                    Card(
                      color: context.appColors.tertiaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: context.appColors.warning,
                                ),
                                const Gap(8),
                                Expanded(
                                  child: BBText(
                                    context.loc.confidentialSepaWarningTitle,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: context.appColors.secondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Gap(8),
                            BBText(
                              context.loc.confidentialSepaWarningDesc,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: context.appColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Gap(24.0),

                    // Account owner name field
                    BBText(
                      context.loc.accountOwnerName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Gap(8),
                    if (userFullName.isEmpty)
                      const LoadingLineContent(height: 56)
                    else
                      TextFormField(
                        enabled: false,
                        initialValue: userFullName,
                        decoration: InputDecoration(
                          fillColor: context.appColors.surfaceContainerHighest,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide(
                              color: context.appColors.secondaryFixedDim,
                            ),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide(
                              color: context.appColors.secondaryFixedDim
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                        ),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: context.appColors.outline,
                        ),
                      ),
                    const Gap(24.0),

                    // Checkbox confirmation
                    CheckboxListTile(
                      tileColor: context.appColors.secondaryFixedDim,
                      contentPadding: const EdgeInsets.all(8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      value: nameConfirmed,
                      onChanged: isCreating
                          ? null
                          : (value) {
                              context.read<VirtualIbanBloc>().add(
                                    VirtualIbanEvent.nameConfirmationToggled(
                                      confirmed: value ?? false,
                                    ),
                                  );
                            },
                      title: BBText(
                        context.loc.confirmLegalName,
                        style: theme.textTheme.bodyLarge,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),

                    // Error message
                    if (error != null) ...[
                      const Gap(16),
                      Card(
                        color: context.appColors.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: BBText(
                            error.toString(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: context.appColors.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom buttons
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCreating)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      BBButton.big(
                        label: context.loc.activateConfidentialSepa,
                        disabled: !nameConfirmed || isCreating,
                        onPressed: () {
                          context.read<VirtualIbanBloc>().add(
                                const VirtualIbanEvent.createRequested(),
                              );
                        },
                        bgColor: context.appColors.primary,
                        textColor: context.appColors.onPrimary,
                      ),
                      const Gap(12),
                      BBButton.big(
                        label: context.loc.useRegularSepaInstead,
                        onPressed: () {
                          context.read<RecipientsBloc>().add(
                                const RecipientsEvent.fallbackToRegularSepa(),
                              );
                        },
                        bgColor: context.appColors.transparent,
                        textColor: context.appColors.secondary,
                        outlined: true,
                        borderColor: context.appColors.secondary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 20,
            color: context.appColors.primary,
          ),
          const Gap(8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class _PendingView extends StatelessWidget {
  const _PendingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: '',
          bullLogo: true,
          onBack: () => _handleBack(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.hourglass_empty,
                        size: 64,
                        color: context.appColors.primary,
                      ),
                      const Gap(24),
                      BBText(
                        context.loc.activatingConfidentialSepaTitle,
                        style: theme.textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const Gap(16),
                      BBText(
                        context.loc.activatingConfidentialSepaDesc,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: context.appColors.outline,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Gap(32),
                      const CircularProgressIndicator(),
                    ],
                  ),
                ),
              ),
            ),

            // Fallback button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: BBButton.big(
                  label: context.loc.useRegularSepaInstead,
                  onPressed: () {
                    context.read<RecipientsBloc>().add(
                          const RecipientsEvent.fallbackToRegularSepa(),
                        );
                  },
                  bgColor: context.appColors.transparent,
                  textColor: context.appColors.secondary,
                  outlined: true,
                  borderColor: context.appColors.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivatedView extends StatelessWidget {
  const _ActivatedView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipientsLocation = context.select(
      (RecipientsBloc bloc) => bloc.state.allowedRecipientFilters.location,
    );

    // Get appropriate description based on location
    final activatedDesc = switch (recipientsLocation) {
      RecipientsLocation.sellView =>
        context.loc.confidentialSepaActivatedSellDesc,
      RecipientsLocation.withdrawView =>
        context.loc.confidentialSepaActivatedWithdrawDesc,
      _ => context.loc.confidentialSepaActivatedSellDesc,
    };

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: const TopBar(
          title: '',
          bullLogo: true,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 64,
                  color: context.appColors.primary,
                ),
                const Gap(24),
                BBText(
                  context.loc.confidentialSepaActivatedTitle,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const Gap(16),
                BBText(
                  activatedDesc,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: context.appColors.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.exception});

  final Exception exception;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: '',
          bullLogo: true,
          onBack: () => _handleBack(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: context.appColors.error,
                ),
                const Gap(24),
                BBText(
                  'Error',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Gap(16),
                BBText(
                  exception.toString(),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: context.appColors.error,
                      ),
                  textAlign: TextAlign.center,
                ),
                const Gap(32),
                BBButton.big(
                  label: context.loc.recoverbullRetry,
                  onPressed: () {
                    context.read<VirtualIbanBloc>().add(
                          const VirtualIbanEvent.started(),
                        );
                  },
                  bgColor: context.appColors.primary,
                  textColor: context.appColors.onPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _handleBack(BuildContext context) {
  // First, try to pop the navigation
  if (context.canPop()) {
    context.pop();
  }
  // Also go back to the recipient type selection step
  context.read<RecipientsBloc>().add(
        const RecipientsEvent.previousStepPressed(),
      );
}
