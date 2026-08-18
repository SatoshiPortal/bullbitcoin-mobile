import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/features/dca/domain/dca.dart';
import 'package:bb_mobile/features/dca/presentation/dca_bloc.dart';
import 'package:bb_mobile/features/dca/ui/widgets/dca_confirmation_detail_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class DcaConfirmationScreen extends StatelessWidget {
  const DcaConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final confirmationState = context.watch<DcaBloc>().state;

    if (confirmationState is! DcaConfirmationState) {
      return const LoadingBoxContent(height: 200);
    }

    return BullPage(
      topBar: BullTopBar(
        title: context.loc.dcaConfirmTitle,
        onBack: context.pop,
      ),
      safeArea: false,
      child: SafeArea(
        child: BullScrollableColumn(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          crossAxisAlignment: .start,
          children: [
            BullFadingLinearProgress(
              height: 3,
              trigger: confirmationState.isConfirmingDca,
              backgroundColor: context.bull.surface,
              foregroundColor: context.bull.primary,
            ),
            const Gap(24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                context.loc.dcaConfirmAutoMessage,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: .center,
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
            Divider(color: context.appColors.outline),
            DcaConfirmationDetailRow(
              label: context.loc.dcaConfirmAmount,
              value: FormatAmount.fiat(
                confirmationState.amount,
                confirmationState.currency.code,
              ),
            ),
            Divider(color: context.appColors.outline),
            DcaConfirmationDetailRow(
              label: context.loc.dcaConfirmPaymentMethod,
              value: context.loc.dcaConfirmPaymentBalance(
                confirmationState.currency.code.toUpperCase(),
              ),
            ),
            Divider(color: context.appColors.outline),
            DcaConfirmationDetailRow(
              label: context.loc.dcaConfirmOrderType,
              value: context.loc.dcaConfirmOrderTypeValue,
            ),
            Divider(color: context.appColors.outline),
            DcaConfirmationDetailRow(
              label: context.loc.dcaConfirmNetwork,
              value: switch (confirmationState.network) {
                DcaNetwork.bitcoin => context.loc.dcaConfirmNetworkBitcoin,
                DcaNetwork.lightning => context.loc.dcaConfirmNetworkLightning,
                DcaNetwork.liquid => context.loc.dcaConfirmNetworkLiquid,
              },
            ),
            if (confirmationState.network == DcaNetwork.lightning) ...[
              Divider(color: context.appColors.outline),
              DcaConfirmationDetailRow(
                label: context.loc.dcaConfirmLightningAddress,
                value: confirmationState.lightningAddress,
              ),
            ],
            const Spacer(),
            if (confirmationState.error != null) ...[
              Text(
                context.loc.dcaConfirmError(
                  confirmationState.error!.toString(),
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.appColors.error),
              ),
              const Gap(16),
            ],
            BullButton.primary(
              label: context.loc.dcaConfirmContinue,
              disabled: confirmationState.isConfirmingDca,
              onPressed: () {
                context.read<DcaBloc>().add(const DcaEvent.confirmed());
              },
            ),
            const Gap(16.0),
          ],
        ),
      ),
    );
  }
}
