import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/virtual_iban/presentation/virtual_iban_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

/// The intro/activation screen for Virtual IBAN (Confidential SEPA).
/// Shows when user has not yet created a Virtual IBAN.
class VirtualIbanIntroScreen extends StatelessWidget {
  const VirtualIbanIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<VirtualIbanBloc>().state;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.confidentialSepaTitle),
        scrolledUnderElevation: 0.0,
      ),
      body: SafeArea(
        child: state.maybeWhen(
          notSubmitted: (
            userSummary,
            location,
            nameConfirmed,
            isCreating,
            error,
          ) =>
              _buildContent(
                context,
                theme,
                nameConfirmed: nameConfirmed,
                isCreating: isCreating,
                userFullName:
                    '${userSummary.profile.firstName} ${userSummary.profile.lastName}'
                        .trim(),
                error: error,
              ),
          loading: () => const Center(child: CircularProgressIndicator()),
          orElse: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Widget _buildContent(
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
                // Title with NEW badge
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

                // Account owner name field (disabled/display only)
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
                          color: context.appColors.secondaryFixedDim.withValues(
                            alpha: 0.5,
                          ),
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
                  onChanged:
                      isCreating
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

        // Bottom button
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child:
                isCreating
                    ? const Center(child: CircularProgressIndicator())
                    : BBButton.big(
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
          ),
        ),
      ],
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

