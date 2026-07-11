import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/core/widgets/tables/details_table.dart';
import 'package:bb_mobile/core/widgets/tables/details_table_item.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_send_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_send_state.dart';
import 'package:bb_mobile/features/sp/router.dart';
import 'package:bb_mobile/features/sp/ui/widgets/coin_source_label.dart';
import 'package:bb_mobile/features/sp/ui/widgets/sp_send_appbar_progress.dart';
import 'package:bb_mobile/features/sp/ui/widgets/sp_send_error_text.dart';
import 'package:bull_ui/bull_ui.dart' show BullBadge;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SpSendConfirmPage extends StatelessWidget {
  const SpSendConfirmPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SpSendCubit>().state;
    final simulation = state.txSimulation;
    final recipient = state.recipient;

    final recipientAddress = recipient?.address ?? '';
    final truncatedRecipient = StringFormatting.truncateMiddle(
      recipientAddress,
      head: 10,
      tail: 10,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.confirmButton, style: context.font.headlineMedium),
        bottom: SpSendAppBarProgress(
          isLoading: context.select((SpSendCubit c) => c.state.isLoading),
        ),
      ),
      body: SafeArea(
        child: ScrollableColumn(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Gap(24),
                Center(
                  child: Text(
                    context.loc.spSendSatsAmount(
                      FormatAmount.satsGrouped(
                        (state.amountSat ?? BigInt.zero).toInt(),
                      ),
                    ),
                    style: context.font.displaySmall,
                  ),
                ),
                const Gap(16),
                DetailsTable(
                  items: [
                    DetailsTableItem(
                      label: context.loc.spSendToLabel,
                      displayWidget: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            truncatedRecipient,
                            textAlign: TextAlign.end,
                            style: context.font.bodyMedium?.copyWith(
                              color: context.appColors.onSurface,
                            ),
                          ),
                          const Gap(2),
                          _RecipientTypeBadge(recipient: recipient),
                        ],
                      ),
                    ),
                    if (simulation != null) ...[
                      DetailsTableItem(
                        label: context.loc.spSendInputsCount(
                          '${simulation.inputs.length}',
                        ),
                        initiallyExpanded: true,
                        displayWidget: const SizedBox.shrink(),
                        expandableChild: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final coin in simulation.inputs)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: _CoinInputRow(coin: coin),
                              ),
                          ],
                        ),
                      ),
                      DetailsTableItem(
                        label: context.loc.spSendOutputsCount(
                          '${simulation.outputs.length}',
                        ),
                        displayWidget: const SizedBox.shrink(),
                        expandableChild: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final out in simulation.outputs)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: _OutputRow(recipient: out),
                              ),
                          ],
                        ),
                      ),
                      DetailsTableItem(
                        label: context.loc.spFeeLabel,
                        displayValue: context.loc.spSendFeeValue(
                          FormatAmount.satsGrouped(simulation.feeSat.toInt()),
                          '${state.feerate}',
                        ),
                      ),
                      if (simulation.changeSat > BigInt.zero)
                        DetailsTableItem(
                          label: context.loc.spChangeLabel,
                          displayValue: context.loc.spSendSatsAmount(
                            FormatAmount.satsGrouped(
                              simulation.changeSat.toInt(),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BlocSelector<SpSendCubit, SpSendState, SpFailure?>(
                  selector: (s) => s.error,
                  builder: (context, failure) =>
                      SpSendErrorText(failure: failure),
                ),
                BlocSelector<SpSendCubit, SpSendState, bool>(
                  selector: (s) => s.isLoading,
                  builder: (context, isLoading) => BBButton.big(
                    label: context.loc.spSendSignBroadcastButton,
                    onPressed: () async {
                      final cubit = context.read<SpSendCubit>();
                      // Read the ancestor SP cubit before the await so we don't
                      // touch context across an async gap.
                      final spCubit = context.read<SpCubit>();
                      await cubit.signAndBroadcast();
                      if (!context.mounted) return;
                      // Advance only after the broadcast succeeded; on failure
                      // the inline error stays on this page.
                      if (cubit.state.sendSuccess) {
                        // Eagerly refresh the wallet for immediate spend
                        // feedback (the spend nets into the unconfirmed balance).
                        unawaited(spCubit.refresh());
                        context.goNamed(SpRoute.spSendSuccess.name);
                      }
                    },
                    disabled: isLoading,
                    bgColor: context.appColors.secondary,
                    textColor: context.appColors.onSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipientTypeBadge extends StatelessWidget {
  const _RecipientTypeBadge({required this.recipient});
  final SpRecipient? recipient;

  @override
  Widget build(BuildContext context) {
    if (recipient == null) return const SizedBox.shrink();
    final isSp = recipient is SpRecipientSp;
    final color = isSp ? context.appColors.success : context.appColors.primary;
    return BullBadge(
      label: isSp ? context.loc.spAddressTypeSilentPayment : context.loc.spBitcoin,
      background: color.withValues(alpha: 0.15),
      foreground: color,
      radius: 4,
      border: Border.all(color: color),
    );
  }
}

class _CoinInputRow extends StatelessWidget {
  const _CoinInputRow({required this.coin});
  final SpCoin coin;

  @override
  Widget build(BuildContext context) {
    final sourceColor = coin.source.sourceColor(context);
    final truncated = StringFormatting.truncateMiddle(
      coin.outpoint,
      head: 8,
      tail: 0,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        BullBadge(
          label: coin.source.shortLabel(context),
          background: sourceColor.withValues(alpha: 0.15),
          foreground: sourceColor,
          radius: 4,
          border: Border.all(color: sourceColor),
        ),
        const Gap(8),
        Text(
          context.loc.spDotAmountSats(
            truncated,
            FormatAmount.satsGrouped(coin.amountSat.toInt()),
          ),
          style: context.font.bodySmall?.copyWith(
            color: context.appColors.onSurface,
          ),
        ),
      ],
    );
  }
}

class _OutputRow extends StatelessWidget {
  const _OutputRow({required this.recipient});
  final SpRecipient recipient;

  @override
  Widget build(BuildContext context) {
    final truncated = StringFormatting.truncateMiddle(recipient.address);
    return Text(
      context.loc.spDotAmountSats(
        truncated,
        FormatAmount.satsGrouped(recipient.amountSat.toInt()),
      ),
      textAlign: TextAlign.end,
      style: context.font.bodySmall?.copyWith(
        color: context.appColors.onSurface,
      ),
    );
  }
}
