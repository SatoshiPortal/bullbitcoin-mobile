import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/ui/widgets/coin_selection_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class AdvancedOptionsBottomSheet extends StatelessWidget {
  const AdvancedOptionsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final isRBFEnabled = context.select(
      (SendCubit cubit) => cubit.state.replaceByFee,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: context.appColors.onSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: .min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: BBText(
                  context.loc.sendAdvancedOptions,
                  style: context.font.headlineMedium,
                  color: context.appColors.secondary,
                ),
              ),
              Positioned(
                right: 0,
                child: IconButton(
                  iconSize: 24,
                  icon: Icon(
                    Icons.close,
                    color: context.appColors.secondary,
                  ),
                  onPressed: context.pop,
                ),
              ),
            ],
          ),
          const Gap(32),
          Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              BBText(
                context.loc.sendReplaceByFeeActivated,
                style: context.font.headlineMedium,
                color: context.appColors.secondary,
              ),
              Switch(
                value: isRBFEnabled,
                onChanged:
                    (val) async => await context
                        .read<SendCubit>()
                        .replaceByFeeChanged(val),
              ),
            ],
          ),
          const Gap(24),
          ListTile(
            title: BBText(
              context.loc.sendSelectCoinsManually,
              style: context.font.bodyLarge?.copyWith(
                fontWeight: .w500,
              ),
              color: context.appColors.secondary,
            ),
            trailing: Icon(
              Icons.arrow_forward,
              color: context.appColors.secondary,
            ),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: context.appColors.onSecondary,
                constraints: const BoxConstraints(maxWidth: double.infinity),
                useSafeArea: true,
                builder:
                    (BuildContext buildContext) => BlocProvider.value(
                      value: context.read<SendCubit>(),
                      child: const CoinSelectionBottomSheet(),
                    ),
              );
            },
          ),
          const Gap(24),
          BBButton.big(
            label: context.loc.sendDone,
            onPressed: context.pop,
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
          ),
          const Gap(24),
        ],
      ),
    );
  }
}
