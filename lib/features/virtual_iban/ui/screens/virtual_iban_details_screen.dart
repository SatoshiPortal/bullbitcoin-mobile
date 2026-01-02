import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/virtual_iban/presentation/virtual_iban_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

/// Screen showing the activated Virtual IBAN details.
/// Displays IBAN, BIC, bank address, recipient name, etc.
class VirtualIbanDetailsScreen extends StatelessWidget {
  const VirtualIbanDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<VirtualIbanBloc>().state;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.privacyBankingTitle),
        scrolledUnderElevation: 0.0,
      ),
      body: SafeArea(
        child: state.maybeWhen(
          active: (recipient, userSummary, location) => SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(8.0),

                // Title with NEW badge
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

                // Warning about name matching
                Card(
                  color: context.appColors.warningContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: context.appColors.warning,
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

                // Virtual IBAN Account Number
                _VirtualIbanDetailField(
                  label: context.loc.virtualIbanAccountNumber,
                  value: recipient.iban,
                ),
                const Gap(24.0),

                // Recipient Name
                _VirtualIbanDetailField(
                  label: context.loc.recipientName,
                  value:
                      '${userSummary.profile.firstName} ${userSummary.profile.lastName}'
                          .trim(),
                ),
                const Gap(24.0),

                // Bank Account Country
                _VirtualIbanDetailField(
                  label: context.loc.bankAccountCountry,
                  value: recipient.ibanCountry ?? 'France',
                ),
                const Gap(24.0),

                // Bank Address
                _VirtualIbanDetailField(
                  label: context.loc.bankAddress,
                  value: recipient.bankAddress,
                ),
                const Gap(24.0),

                // BIC Code
                _VirtualIbanDetailField(
                  label: context.loc.bicCode,
                  value: recipient.bicCode,
                ),
                const Gap(24.0),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          orElse: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

/// A copyable detail field for Virtual IBAN details.
class _VirtualIbanDetailField extends StatelessWidget {
  const _VirtualIbanDetailField({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const Gap(8.0),
        ListTile(
          title: value != null ? Text(value!) : const LoadingLineContent(),
          trailing: IconButton(
            onPressed: value != null
                ? () {
                    final data = ClipboardData(text: value!);
                    Clipboard.setData(data);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.loc.copiedToClipboard),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.copy),
          ),
        ),
      ],
    );
  }
}
