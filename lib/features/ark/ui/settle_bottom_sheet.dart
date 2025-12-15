import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/widgets/buttons/button.dart';
import 'package:bb_mobile/core_deprecated/widgets/text/text.dart';
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
      backgroundColor: context.appColors.transparent,
      builder: (_) => SettleBottomSheet(cubit: cubit),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: BlocBuilder<ArkCubit, ArkState>(
          bloc: cubit,
          builder: (context, state) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: .min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.appColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Gap(24),
                  Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: context.appColors.primary,
                  ),
                  const Gap(16),
                  BBText(
                    context.loc.arkSettleTitle,
                    style: context.font.headlineSmall?.copyWith(
                      fontWeight: .bold,
                    ),
                    textAlign: .center,
                  ),
                  const Gap(8),
                  BBText(
                    context.loc.arkSettleMessage,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                    textAlign: .center,
                    maxLines: 3,
                  ),
                  const Gap(24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: context.appColors.cardBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: .spaceBetween,
                      children: [
                        BBText(
                          context.loc.arkSettleIncludeRecoverable,
                          style: context.font.bodyMedium,
                        ),
                        Switch(
                          value: state.withRecoverableVtxos,
                          onChanged: cubit.onChangedSelectRecoverableVtxos,
                          activeThumbColor: context.appColors.primary,
                        ),
                      ],
                    ),
                  ),
                  const Gap(24),
                  Row(
                    children: [
                      Expanded(
                        child: BBButton.small(
                          label: context.loc.arkSettleCancel,
                          onPressed: () => Navigator.of(context).pop(),
                          bgColor: context.appColors.cardBackground,
                          textColor: context.appColors.onSurface,
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: BBButton.small(
                          label: context.loc.arkSettleButton,
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await cubit.settle(state.withRecoverableVtxos);
                          },
                          bgColor: context.appColors.primary,
                          textColor: context.appColors.onPrimary,
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
