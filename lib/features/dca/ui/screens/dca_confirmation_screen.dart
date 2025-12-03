import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
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
      appBar: AppBar(title: Text(context.loc.dcaConfirmTitle)),
      body: SafeArea(
        child: ScrollableColumn(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadingLinearProgress(
              height: 3,
              trigger: confirmationState.isConfirmingDca,
              backgroundColor: context.appColors.onPrimary,
              foregroundColor: context.appColors.primary,
            ),
            const Gap(24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                context.loc.dcaConfirmAutoMessage,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const Gap(24),
            DcaConfirmationDetailRow(
              label: context.loc.dcaConfirmFrequency,
              value: switch (confirmationState.frequency) {
                DcaBuyFrequency.hourly => context.loc.dcaConfirmFrequencyHourly,
                DcaBuyFrequency.daily => context.loc.dcaConfirmFrequencyDaily,
                DcaBuyFrequency.weekly => context.loc.dcaConfirmFrequencyWeekly,
                DcaBuyFrequency.monthly =>
                  context.loc.dcaConfirmFrequencyMonthly,
              },
            ),
            Divider(color: context.appColors.surface),
            DcaConfirmationDetailRow(
              label: context.loc.dcaConfirmAmount,
              value: FormatAmount.fiat(
                confirmationState.amount,
                confirmationState.currency.code,
              ),
            ),
            Divider(color: context.appColors.surface),
            DcaConfirmationDetailRow(
              label: context.loc.dcaConfirmPaymentMethod,
              value: context.loc.dcaConfirmPaymentBalance(
                confirmationState.currency.code.toUpperCase(),
              ),
            ),
            Divider(color: context.appColors.surface),
            DcaConfirmationDetailRow(
              label: context.loc.dcaConfirmOrderType,
              value: context.loc.dcaConfirmOrderTypeValue,
            ),
            Divider(color: context.appColors.surface),
            DcaConfirmationDetailRow(
              label: context.loc.dcaConfirmNetwork,
              value: switch (confirmationState.network) {
                DcaNetwork.bitcoin => context.loc.dcaConfirmNetworkBitcoin,
                DcaNetwork.lightning => context.loc.dcaConfirmNetworkLightning,
                DcaNetwork.liquid => context.loc.dcaConfirmNetworkLiquid,
              },
            ),
            if (confirmationState.network == DcaNetwork.lightning) ...[
              Divider(color: context.appColors.surface),
              DcaConfirmationDetailRow(
                label: context.loc.dcaConfirmLightningAddress,
                value: confirmationState.lightningAddress,
              ),
            ],
            const Spacer(),
            if (confirmationState.error != null) ...[
              Text(
                context.loc.dcaConfirmError(confirmationState.error!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appColors.error,
                ),
              ),
              const Gap(16),
            ],
            BBButton.big(
              label: context.loc.dcaConfirmContinue,
              disabled: confirmationState.isConfirmingDca,
              onPressed: () {
                context.read<DcaBloc>().add(const DcaEvent.confirmed());
              },
              bgColor: context.appColors.secondary,
              textColor: context.appColors.onSecondary,
            ),
            const Gap(16.0),
          ],
        ),
      ),
    );
  }
}
