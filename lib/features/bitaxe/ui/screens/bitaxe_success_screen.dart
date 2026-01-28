import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitaxe/presentation/bloc/bitaxe_bloc.dart';
import 'package:bb_mobile/features/bitaxe/presentation/bloc/bitaxe_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BitaxeSuccessScreen extends StatelessWidget {
  const BitaxeSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      body: BlocBuilder<BitaxeBloc, BitaxeState>(
        builder: (context, state) {
          final device = state.device;
          final systemInfo = device?.systemInfo;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Gap(32),
                // Success Icon
                Icon(
                  Icons.check_circle,
                  size: 80,
                  color: context.appColors.success,
                ),
                const Gap(24),
                // Success Title
                BBText(
                  'Device Connected Successfully!',
                  style: context.font.headlineMedium,
                  color: context.appColors.text,
                  textAlign: TextAlign.center,
                ),
                const Gap(16),
                // Educational Message
                InfoCard(
                  description:
                      'When you successfully mine a block with this Bitaxe solo miner, the reward will be sent directly to your wallet address.',
                  tagColor: context.appColors.primary,
                  bgColor: context.appColors.surfaceContainerHighest,
                ),
                const Gap(24),
                // Device Info (if available)
                if (systemInfo != null) ...[
                  BBText(
                    'Device Information',
                    style: context.font.headlineSmall,
                    color: context.appColors.text,
                  ),
                  const Gap(8),
                  Card(
                    color: context.appColors.cardBackground,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoRow(
                            label: 'Board Version',
                            value: systemInfo.boardVersion,
                            context: context,
                          ),
                          const Gap(8),
                          _InfoRow(
                            label: 'ASIC Type',
                            value: systemInfo.asicModel,
                            context: context,
                          ),
                          if (systemInfo.primaryPool.bitcoinAddress !=
                              null) ...[
                            const Gap(8),
                            _InfoRow(
                              label: 'Mining Address',
                              value: systemInfo.primaryPool.bitcoinAddress!,
                              context: context,
                              highlight: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Gap(24),
                ],
                // Done Button
                BBButton.big(
                  label: 'Done',
                  onPressed: () => context.pop(),
                  bgColor: context.appColors.primary,
                  textColor: context.appColors.onPrimary,
                ),
                const Gap(16),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.context,
    this.highlight = false,
  });

  final String label;
  final String value;
  final BuildContext context;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: BBText(
            label,
            style: this.context.font.bodyMedium,
            color: this.context.appColors.textMuted,
          ),
        ),
        Expanded(
          child: BBText(
            value,
            style: this.context.font.bodyMedium,
            color: highlight
                ? this.context.appColors.primary
                : this.context.appColors.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
