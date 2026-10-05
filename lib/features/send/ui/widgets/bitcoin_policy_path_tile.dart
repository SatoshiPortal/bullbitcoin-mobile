import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/tiles/bordered_tappable_tile.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/ui/widgets/bitcoin_policy_description.dart';
import 'package:bb_mobile/features/send/ui/widgets/bitcoin_policy_path_bottom_sheet.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BitcoinPolicyPathTile extends StatelessWidget {
  const BitcoinPolicyPathTile({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SendCubit>().state;
    final policy = state.bitcoinSigningPlan?.policy;
    if (policy == null ||
        (!policy.requiresPath && !policy.hasTimelock && !policy.hasHashlock)) {
      return const SizedBox.shrink();
    }

    final needsSelection = state.requiresBitcoinPolicySelection;
    final canChooseNow = needsSelection && bitcoinPolicyCanChoosePathNow(state);
    final activation = state.nextBitcoinPolicyActivation;
    final needsPreimage = state.requiresBitcoinPolicyPreimage;
    final summary = canChooseNow
        ? context.loc.sendSpendingPathRequired
        : needsSelection && activation != null
        ? describeBitcoinPolicyActivation(context, activation)
        : needsSelection
        ? context.loc.sendPolicyNoPathAvailable
        : needsPreimage
        ? context.loc.walletPolicyHashPreimage
        : describeSelectedBitcoinPolicyPath(
            context,
            state.selectedWallet,
            state,
          );
    return BorderedTappableTile(
      onTap: () => BlurredBottomSheet.show<void>(
        context: context,
        isDismissible: false,
        child: BlocProvider.value(
          value: context.read<SendCubit>(),
          child: const BitcoinPolicyPathBottomSheet(),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText(
                  context.loc.sendAuthorization,
                  style: context.font.bodyLarge?.copyWith(fontWeight: .w500),
                  color: context.appColors.secondary,
                ),
                const Gap(4),
                BBText(
                  summary,
                  style: context.font.bodySmall,
                  color: (needsSelection && !canChooseNow) || needsPreimage
                      ? context.appColors.error
                      : context.appColors.textMuted,
                ),
              ],
            ),
          ),
          const Gap(12),
          Icon(Icons.arrow_forward, color: context.appColors.secondary),
        ],
      ),
    );
  }
}
