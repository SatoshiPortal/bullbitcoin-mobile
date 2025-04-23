import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/ui/widgets/coin_selection_bottom_sheet.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/components/toggle/switch.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
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
                child: BBText(
                  "Advanced options",
                  style: context.font.headlineMedium,
                ),
              ),
              Positioned(
                right: 0,
                child: IconButton(
                  iconSize: 24,
                  icon: const Icon(Icons.close),
                  onPressed: context.pop,
                ),
              ),
            ],
          ),
          const Gap(32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BBText(
                "Replace-by-fee activated",
                style: context.font.headlineMedium,
              ),
              BBSwitch(
                value: isRBFEnabled,
                onChanged: (val) =>
                    context.read<SendCubit>().replaceByFeeChanged(val),
              ),
            ],
          ),
          const Gap(24),
          ListTile(
            tileColor: context.colour.onPrimary,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: context.colour.surface,
              ),
            ),
            title: BBText(
              "Select coins manually",
              style: context.font.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: context.colour.secondaryFixed,
                useSafeArea: true,
                builder: (BuildContext buildContext) => BlocProvider.value(
                  value: context.read<SendCubit>(),
                  child: const CoinSelectionBottomSheet(),
                ),
              );
            },
          ),
          const Gap(24),
          BBButton.big(
            label: "Done",
            onPressed: context.pop,
            bgColor: context.colour.secondary,
            textColor: context.colour.onSecondary,
          ),
          const Gap(24),
        ],
      ),
    );
  }
}
