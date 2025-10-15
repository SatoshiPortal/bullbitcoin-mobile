import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/ark/presentation/cubit.dart';
import 'package:bb_mobile/features/ark/presentation/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SettleBottomSheet extends StatelessWidget {
  const SettleBottomSheet({super.key, required this.cubit});

  final ArkCubit cubit;

  static Future<void> show(BuildContext context, ArkCubit cubit) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SettleBottomSheet(cubit: cubit),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colour.onPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: BlocBuilder<ArkCubit, ArkState>(
          bloc: cubit,
          builder: (context, state) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.colour.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Gap(24),
                  Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: context.colour.primary,
                  ),
                  const Gap(16),
                  BBText(
                    'Settle Transactions',
                    style: context.font.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Gap(8),
                  BBText(
                    'Finalize pending transactions and include recoverable vtxos if needed',
                    style: context.font.bodyMedium?.copyWith(
                      color: context.colour.secondary.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                  ),
                  const Gap(24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: context.colour.surface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        BBText(
                          'Include recoverable vtxos',
                          style: context.font.bodyMedium,
                        ),
                        Switch(
                          value: state.withRecoverableVtxos,
                          onChanged: cubit.onChangedSelectRecoverableVtxos,
                          activeColor: context.colour.primary,
                        ),
                      ],
                    ),
                  ),
                  const Gap(24),
                  Row(
                    children: [
                      Expanded(
                        child: BBButton.small(
                          label: 'Cancel',
                          onPressed: () => Navigator.of(context).pop(),
                          bgColor: context.colour.secondaryFixed,
                          textColor: context.colour.secondary,
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: BBButton.small(
                          label: 'Settle',
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await cubit.settle(state.withRecoverableVtxos);
                          },
                          bgColor: context.colour.primary,
                          textColor: context.colour.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
