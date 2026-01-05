import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_method_list_tile.dart';
import 'package:bb_mobile/features/virtual_iban/domain/virtual_iban_location.dart';
import 'package:bb_mobile/features/virtual_iban/presentation/virtual_iban_bloc.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class FundExchangeEuropeMethods extends StatelessWidget {
  const FundExchangeEuropeMethods({super.key});

  @override
  Widget build(BuildContext context) {
    final userSummary = context.select(
      (FundExchangeBloc bloc) => bloc.state.userSummary,
    );
    final isFullyVerifiedKyc = userSummary?.isFullyVerifiedKycLevel ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Confidential SEPA - only for fully verified KYC users
        if (isFullyVerifiedKyc) ...[
          _ConfidentialSepaMethodTile(),
          const Gap(16.0),
        ],
        FundExchangeMethodListTile(
          method: FundingMethod.instantSepa,
          title: context.loc.fundExchangeMethodInstantSepa,
          subtitle: context.loc.fundExchangeMethodInstantSepaSubtitle,
        ),
        const Gap(16.0),
        FundExchangeMethodListTile(
          method: FundingMethod.regularSepa,
          title: context.loc.fundExchangeMethodRegularSepa,
          subtitle: context.loc.fundExchangeMethodRegularSepaSubtitle,
        ),
      ],
    );
  }
}

/// Tile for Confidential SEPA / Virtual IBAN funding method.
class _ConfidentialSepaMethodTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      tileColor: context.appColors.transparent,
      shape: const RoundedRectangleBorder(),
      title: Row(
        children: [
          Text(context.loc.confidentialSepaTitle),
          const Gap(8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
      subtitle: Text(
        context.loc.fundExchangeMethodConfidentialSepaSubtitle,
        style: theme.textTheme.labelMedium!.copyWith(
          color: context.appColors.outline,
        ),
      ),
      onTap: () {
        _navigateToConfidentialSepa(context);
      },
      trailing: const Icon(Icons.arrow_forward),
    );
  }

  void _navigateToConfidentialSepa(BuildContext context) {
    // Navigate to the Confidential SEPA / Virtual IBAN flow
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (navContext) => BlocProvider(
          create: (_) =>
              locator<VirtualIbanBloc>(param1: VirtualIbanLocation.funding)
                ..add(const VirtualIbanEvent.started()),
          child: const _VirtualIbanFlowScreen(),
        ),
      ),
    );
  }
}

/// Screen that shows the Virtual IBAN flow based on state.
class _VirtualIbanFlowScreen extends StatelessWidget {
  const _VirtualIbanFlowScreen();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VirtualIbanBloc, VirtualIbanState>(
      listener: (context, state) {
        // Handle state transitions if needed
      },
      builder: (context, state) {
        return state.when(
          initial: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          notSubmitted: (_, _, _, _, _) {
            // Dynamically import to avoid circular dependency
            return const _VirtualIbanIntroScreenWrapper();
          },
          pending: (_, _, _, _) {
            return const _VirtualIbanPendingScreenWrapper();
          },
          active: (_, _, _) {
            return const _VirtualIbanActiveScreenWrapper();
          },
          error: (exception) => Scaffold(
            appBar: AppBar(title: Text(context.loc.error)),
            body: Center(child: Text('$exception')),
          ),
        );
      },
    );
  }
}

class _VirtualIbanIntroScreenWrapper extends StatelessWidget {
  const _VirtualIbanIntroScreenWrapper();

  @override
  Widget build(BuildContext context) {
    // Use a delayed import approach
    return Builder(
      builder: (context) {
        return const _VirtualIbanIntroContent();
      },
    );
  }
}

class _VirtualIbanPendingScreenWrapper extends StatelessWidget {
  const _VirtualIbanPendingScreenWrapper();

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return const _VirtualIbanPendingContent();
      },
    );
  }
}

class _VirtualIbanActiveScreenWrapper extends StatelessWidget {
  const _VirtualIbanActiveScreenWrapper();

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return const _VirtualIbanActiveContent();
      },
    );
  }
}

// Content widgets that replicate the screen functionality inline
// to avoid import issues with the virtual_iban feature
class _VirtualIbanIntroContent extends StatelessWidget {
  const _VirtualIbanIntroContent();

  @override
  Widget build(BuildContext context) {
    // Import the screen directly
    return BlocBuilder<VirtualIbanBloc, VirtualIbanState>(
      builder: (context, state) {
        return state.maybeWhen(
          notSubmitted: (userSummary, location, nameConfirmed, isCreating, error) {
            final theme = Theme.of(context);
            final userFullName =
                '${userSummary.profile.firstName} ${userSummary.profile.lastName}'
                    .trim();

            return Scaffold(
              appBar: AppBar(title: Text(context.loc.confidentialSepaTitle)),
              body: _buildIntroBody(
                context,
                theme,
                nameConfirmed: nameConfirmed,
                isCreating: isCreating,
                userFullName: userFullName,
                error: error,
              ),
            );
          },
          orElse: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      },
    );
  }

  Widget _buildIntroBody(
    BuildContext context,
    ThemeData theme, {
    required bool nameConfirmed,
    required bool isCreating,
    required String userFullName,
    Exception? error,
  }) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Gap(16.0),
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
                              color: context.appColors.secondary,
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
                BBText(
                  context.loc.accountOwnerName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(8),
                TextFormField(
                  enabled: false,
                  initialValue: userFullName,
                  decoration: InputDecoration(
                    fillColor: context.appColors.surfaceContainerHighest,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: context.appColors.outline,
                  ),
                ),
                const Gap(24.0),
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
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: isCreating
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: nameConfirmed
                          ? () {
                              context.read<VirtualIbanBloc>().add(
                                const VirtualIbanEvent.createRequested(),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.appColors.primary,
                        foregroundColor: context.appColors.onPrimary,
                      ),
                      child: Text(context.loc.activateConfidentialSepa),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _VirtualIbanPendingContent extends StatelessWidget {
  const _VirtualIbanPendingContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.confidentialSepaTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: context.appColors.surfaceContainer,
                  child: Icon(
                    Icons.schedule,
                    size: 48,
                    color: context.appColors.onSurface,
                  ),
                ),
                const Gap(24.0),
                BBText(
                  context.loc.activatingConfidentialSepaTitle,
                  style: theme.textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const Gap(16.0),
                BBText(
                  context.loc.activatingConfidentialSepaDesc,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const Gap(32.0),
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    backgroundColor: context.appColors.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.appColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.loc.useRegularSepaInstead),
          ),
        ),
      ),
    );
  }
}

class _VirtualIbanActiveContent extends StatelessWidget {
  const _VirtualIbanActiveContent();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VirtualIbanBloc, VirtualIbanState>(
      builder: (context, state) {
        return state.maybeWhen(
          active: (recipient, userSummary, location) {
            final theme = Theme.of(context);

            return Scaffold(
              appBar: AppBar(title: Text(context.loc.privacyBankingTitle)),
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Gap(8.0),
                      Row(
                        children: [
                          BBText(
                            context.loc.privacyBankingTitle,
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
                      const Gap(24.0),
                      Card(
                        color: context.appColors.tertiaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: context.appColors.secondary,
                              ),
                              const Gap(8),
                              Expanded(
                                child: BBText(
                                  context.loc.virtualIbanNameWarning,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: context.appColors.secondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Gap(24.0),
                      _DetailField(
                        label: context.loc.virtualIbanAccountNumber,
                        value: recipient.iban ?? '',
                        context: context,
                      ),
                      const Gap(24.0),
                      _DetailField(
                        label: context.loc.recipientName,
                        value:
                            '${userSummary.profile.firstName} ${userSummary.profile.lastName}'
                                .trim(),
                        context: context,
                      ),
                      const Gap(24.0),
                      _DetailField(
                        label: context.loc.bankAccountCountry,
                        value: recipient.ibanCountry ?? 'France',
                        context: context,
                      ),
                      const Gap(24.0),
                      _DetailField(
                        label: context.loc.bankAddress,
                        value: recipient.bankAddress ?? '',
                        context: context,
                      ),
                      const Gap(24.0),
                      _DetailField(
                        label: context.loc.bicCode,
                        value: recipient.bicCode ?? '',
                        context: context,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          orElse: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      },
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({
    required this.label,
    required this.value,
    required this.context,
  });

  final String label;
  final String value;
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const Gap(8.0),
        ListTile(
          title: Text(value),
          trailing: IconButton(
            onPressed: () {
              // Copy to clipboard
            },
            icon: const Icon(Icons.copy),
          ),
        ),
      ],
    );
  }
}
