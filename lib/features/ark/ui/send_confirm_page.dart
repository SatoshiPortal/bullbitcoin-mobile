import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/ark/presentation/cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SendConfirmPage extends StatelessWidget {
  const SendConfirmPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select((ArkCubit cubit) => cubit.state.isLoading);
    final error = context.select((ArkCubit cubit) => cubit.state.error);
    final recipient = context.select(
      (ArkCubit cubit) => cubit.state.sendAddress?.address ?? '',
    );
    final bitcoinUnit = context.select(
      (ArkCubit cubit) => cubit.state.preferredBitcoinUnit,
    );
    final amountSat = context.select((ArkCubit cubit) => cubit.state.amountSat);
    final fiatCurrencyCode = context.select(
      (ArkCubit cubit) =>
          cubit.state.fiatCurrencyCodes.contains(cubit.state.currencyCode)
              ? cubit.state.currencyCode
              : cubit.state.preferrredFiatCurrencyCode,
    );
    final exchangeRate = context.select(
      (ArkCubit cubit) => cubit.state.exchangeRate,
    );

    final bitcoinAmount =
        bitcoinUnit == BitcoinUnit.btc
            ? (amountSat != null ? amountSat / 1e8 : 0)
            : (amountSat ?? 0);

    final fiatAmount =
        amountSat != null
            ? (amountSat / 1e8 * exchangeRate).toStringAsFixed(2)
            : '0';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.loc.arkSendConfirmTitle,
          style: context.font.headlineMedium,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child:
              isLoading
                  ? FadingLinearProgress(
                    height: 3,
                    trigger: isLoading,
                    backgroundColor: context.colorScheme.surface,
                    foregroundColor: context.colorScheme.primary,
                  )
                  : const SizedBox(height: 3),
        ),
      ),
      body: SafeArea(
        child: ScrollableColumn(
          children: [
            Column(
              children: [
                const SizedBox(height: 24),
                Text(
                  context.loc.arkSendConfirmMessage,
                  style: context.font.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SendConfirmationDetailRow(
                  label: context.loc.arkRecipientAddress,
                  value: recipient,
                ),
                SendConfirmationDetailRow(
                  label: context.loc.arkAmount,
                  value:
                      '${bitcoinAmount.toStringAsFixed(bitcoinUnit == BitcoinUnit.btc ? 8 : 0)} ${bitcoinUnit.code}\n'
                      '(~ $fiatAmount $fiatCurrencyCode)',
                ),
              ],
            ),
            const Spacer(),
            if (error != null) ...[
              Text(
                error.message,
                style: context.font.bodyMedium?.copyWith(
                  color: context.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            BBButton.big(
              label: context.loc.arkConfirmButton,
              onPressed: () {
                context.read<ArkCubit>().onSendConfirmed();
              },
              disabled: isLoading,
              bgColor: context.colorScheme.secondary,
              textColor: context.colorScheme.onSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class SendConfirmationDetailRow extends StatelessWidget {
  final String label;
  final String? value;

  const SendConfirmationDetailRow({super.key, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.surfaceContainer,
            ),
          ),
          const Gap(8),
          Expanded(
            child:
                value == null
                    ? const LoadingLineContent()
                    : Text(
                      value!,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
