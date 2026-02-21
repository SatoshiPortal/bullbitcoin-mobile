import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/labeled_text_input.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/features/manual_swap_status_reset/presentation/cubit/manual_swap_status_reset_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class _CopyableIndexRow extends StatelessWidget {
  const _CopyableIndexRow({
    required this.label,
    required this.value,
    required this.onCopied,
  });

  final String label;
  final String value;
  final VoidCallback onCopied;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BBText(
            '$label: $value',
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.onSurfaceVariant,
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            onCopied();
          },
          icon: Icon(
            Icons.copy,
            size: 18,
            color: context.appColors.primary,
          ),
          tooltip: context.loc.manualSwapStatusResetCopyMetadata,
        ),
      ],
    );
  }
}

class ManualSwapStatusResetScreen extends StatelessWidget {
  const ManualSwapStatusResetScreen({super.key});

  static String _formatSwapMetadata(Swap swap) {
    final type = swap.type.name;
    final status = swap.status.name;
    final amount = swap.amountSat;
    final created = swap.creationTime.toIso8601String();
    final sendTx = swap.sendTxId ?? '-';
    final receiveTx = swap.receiveTxId ?? '-';
    return 'Type: $type\nStatus: $status\nAmount: $amount sats\nCreated: $created\nSend TxId: $sendTx\nReceive TxId: $receiveTx';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.manualSwapStatusResetTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: BlocBuilder<ManualSwapStatusResetCubit,
              ManualSwapStatusResetState>(
            buildWhen: (p, c) => p.isLoading != c.isLoading,
            builder: (context, state) {
              return state.isLoading
                  ? FadingLinearProgress(
                      height: 3,
                      trigger: true,
                      backgroundColor: context.appColors.surface,
                      foregroundColor: context.appColors.primary,
                    )
                  : const SizedBox(height: 3);
            },
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Gap(16),
                InfoCard(
                  description: context.loc.manualSwapStatusResetWarning,
                  tagColor: context.appColors.error,
                  bgColor: context.appColors.errorContainer,
                  boldDescription: true,
                ),
                const Gap(16),
                BlocBuilder<ManualSwapStatusResetCubit,
                    ManualSwapStatusResetState>(
                  builder: (context, state) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LabeledTextInput(
                          label: context.loc.manualSwapStatusResetSwapIdLabel,
                          value: state.swapId ?? '',
                          hint: context.loc.manualSwapStatusResetSwapIdHint,
                          onChanged: (v) => context
                              .read<ManualSwapStatusResetCubit>()
                              .updateSwapId(v),
                        ),
                        const Gap(8),
                        BBButton.small(
                          label: context.loc.manualSwapStatusResetLookup,
                          onPressed: () {
                            context
                                .read<ManualSwapStatusResetCubit>()
                                .findAndUpdateSwapStatusById(state.swapId ?? '');
                          },
                          bgColor: context.appColors.primary,
                          textColor: context.appColors.onPrimary,
                        ),
                        if (state.errorMessage != null) ...[
                          const Gap(12),
                          InfoCard(
                            description: state.errorMessage!,
                            tagColor: context.appColors.error,
                            bgColor: context.appColors.errorContainer,
                            onTap: () => context
                                .read<ManualSwapStatusResetCubit>()
                                .clearMessages(),
                          ),
                          if (state.nextReverseIndex != null ||
                              state.nextChainIndex != null ||
                              state.nextSubmarineIndex != null) ...[
                            const Gap(12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.appColors.surfaceContainer,
                                borderRadius: BorderRadius.circular(2),
                                border: Border.all(
                                  color: context.appColors.surfaceContainerHighest,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BBText(
                                    context.loc.manualSwapStatusResetIndicesForRescue,
                                    style: context.font.labelMedium?.copyWith(
                                      color: context.appColors.onSurface,
                                    ),
                                  ),
                                  if (state.nextReverseIndex != null) ...[
                                    const Gap(8),
                                    _CopyableIndexRow(
                                      label: context
                                          .loc.manualSwapStatusResetReverseIndex,
                                      value: state.nextReverseIndex.toString(),
                                      onCopied: () =>
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                        SnackBar(
                                          content: Text(context.loc
                                              .manualSwapStatusResetMetadataCopied),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (state.nextChainIndex != null) ...[
                                    const Gap(8),
                                    _CopyableIndexRow(
                                      label: context
                                          .loc.manualSwapStatusResetChainIndex,
                                      value: state.nextChainIndex.toString(),
                                      onCopied: () =>
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                        SnackBar(
                                          content: Text(context.loc
                                              .manualSwapStatusResetMetadataCopied),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (state.nextSubmarineIndex != null) ...[
                                    const Gap(8),
                                    _CopyableIndexRow(
                                      label: context
                                          .loc.manualSwapStatusResetSubmarineIndex,
                                      value: state.nextSubmarineIndex.toString(),
                                      onCopied: () =>
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                        SnackBar(
                                          content: Text(context.loc
                                              .manualSwapStatusResetMetadataCopied),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                        if (state.successMessage != null) ...[
                          const Gap(12),
                          InfoCard(
                            description: context.loc.manualSwapStatusResetSuccessMessage,
                            tagColor: context.appColors.success,
                            bgColor: context.appColors.surfaceContainer,
                            onTap: () => context
                                .read<ManualSwapStatusResetCubit>()
                                .clearMessages(),
                          ),
                        ],
                        if (state.swap != null) ...[
                          const Gap(16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.appColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(
                                color: context.appColors.surfaceContainerHighest,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    BBText(
                                      context.loc.manualSwapStatusResetMetadataTitle,
                                      style: context.font.labelMedium?.copyWith(
                                        color: context.appColors.onSurface,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(
                                            text: _formatSwapMetadata(state.swap!),
                                          ),
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              context.loc.manualSwapStatusResetMetadataCopied,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: Icon(
                                        Icons.copy,
                                        size: 20,
                                        color: context.appColors.primary,
                                      ),
                                      tooltip: context.loc.manualSwapStatusResetCopyMetadata,
                                    ),
                                  ],
                                ),
                                const Gap(8),
                                BBText(
                                  _formatSwapMetadata(state.swap!),
                                  style: context.font.bodySmall?.copyWith(
                                    color: context.appColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const Gap(24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
