import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/dca/domain/dca.dart';
import 'package:bb_mobile/features/dca/presentation/dca_bloc.dart';
import 'package:bb_mobile/features/dca/ui/widgets/dca_confirmation_detail_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class DcaConfirmationScreen extends StatelessWidget {
  const DcaConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final confirmationState = context.watch<DcaBloc>().state;

    if (confirmationState is! DcaConfirmationState) {
      return const LoadingBoxContent(height: 200);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Recurring Buy')),
      body: SafeArea(
        child: ScrollableColumn(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadingLinearProgress(
              height: 3,
              trigger: confirmationState.isConfirmingDca,
              backgroundColor: context.colour.onPrimary,
              foregroundColor: context.colour.primary,
            ),
            const Gap(24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Buy orders will be placed automatically per these settings. You can disable them anytime.',
                style: context.theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const Gap(24),
            DcaConfirmationDetailRow(
              label: 'Frequency',
              value: switch (confirmationState.frequency) {
                DcaBuyFrequency.hourly => 'Every hour',
                DcaBuyFrequency.daily => 'Every day',
                DcaBuyFrequency.weekly => 'Every week',
                DcaBuyFrequency.monthly => 'Every month',
              },
            ),
            Divider(color: context.colour.surface),
            DcaConfirmationDetailRow(
              label: 'Amount',
              value: FormatAmount.fiat(
                confirmationState.amount,
                confirmationState.currency.code,
              ),
            ),
            Divider(color: context.colour.surface),
            DcaConfirmationDetailRow(
              label: 'Payment method',
              value: '${confirmationState.currency.code.toUpperCase()} balance',
            ),
            Divider(color: context.colour.surface),
            const DcaConfirmationDetailRow(
              label: 'Order type',
              value: 'Recurring buy',
            ),
            Divider(color: context.colour.surface),
            DcaConfirmationDetailRow(
              label: 'Network',
              value: switch (confirmationState.network) {
                DcaNetwork.bitcoin => 'Bitcoin',
                DcaNetwork.lightning => 'Lightning',
                DcaNetwork.liquid => 'Liquid',
              },
            ),
            if (confirmationState.network == DcaNetwork.lightning) ...[
              Divider(color: context.colour.surface),
              DcaConfirmationDetailRow(
                label: 'Lightning address',
                value: confirmationState.lightningAddress,
              ),
            ],
            const Spacer(),
            if (confirmationState.error != null) ...[
              Text(
                'Something went wrong: ${confirmationState.error}',
                style: context.theme.textTheme.bodySmall?.copyWith(
                  color: context.colour.error,
                ),
              ),
              const Gap(16),
            ],
            BBButton.big(
              label: 'Continue',
              disabled: confirmationState.isConfirmingDca,
              onPressed: () {
                context.read<DcaBloc>().add(const DcaEvent.confirmed());
              },
              bgColor: context.colour.secondary,
              textColor: context.colour.onSecondary,
            ),
            const Gap(16.0),
          ],
        ),
      ),
    );
  }
}
