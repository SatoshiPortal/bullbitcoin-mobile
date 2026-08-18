import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/ui/widgets/coin_selection_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
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
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: BullText(
                  context.loc.sendAdvancedOptions,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                  color: context.appColors.secondary,
                ),
              ),
              Positioned(
                right: 0,
                child: IconButton(
                  iconSize: 24,
                  icon: Icon(Icons.close, color: context.appColors.secondary),
                  onPressed: context.pop,
                ),
              ),
            ],
          ),
          const Gap(32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BullText(
                context.loc.sendReplaceByFeeActivated,
                style: Theme.of(context).textTheme.headlineMedium,
                color: context.appColors.secondary,
              ),
              Switch(
                value: isRBFEnabled,
                onChanged: (val) async =>
                    await context.read<SendCubit>().replaceByFeeChanged(val),
              ),
            ],
          ),
          const Gap(24),
          ListTile(
            title: BullText(
              context.loc.sendSelectCoinsManually,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
              color: context.appColors.secondary,
            ),
            trailing: Icon(
              Icons.arrow_forward,
              color: context.appColors.secondary,
            ),
            onTap: () {
              BlurredBottomSheet.show(
                context: context,
                child: BlocProvider.value(
                  value: context.read<SendCubit>(),
                  child: const CoinSelectionBottomSheet(),
                ),
              );
            },
          ),
          const Gap(24),
          BullButton.primary(
            label: context.loc.sendDone,
            onPressed: context.pop,
          ),
          const Gap(24),
        ],
      ),
    );
  }
}
