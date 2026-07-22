import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/address_viewer.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/sp/presentation/sp_send_cubit.dart';
import 'package:bb_mobile/features/sp/router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:gif/gif.dart';
import 'package:go_router/go_router.dart';

class SpSendSuccessScreen extends StatelessWidget {
  const SpSendSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final txid = context.select((SpSendCubit c) => c.state.txid);

    void done() {
      context.read<SpSendCubit>().resetSendFlow();
      context.goNamed(SpRoute.spWalletDetail.name);
    }

    // Intercept system back / iOS swipe-back. Without this, the user
    // lands on the confirm page where a stale simulation + a second tap on
    // Sign & Broadcast could re-enter the broadcast path. The cubit-side
    // fix (clearing simulation on success) is the bedrock; this PopScope is
    // the UX layer that routes the user cleanly back to the wallet detail
    // instead of stranding them on a now-empty confirm page.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        done();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const SizedBox.shrink(),
          actions: [CloseButton(onPressed: done)],
        ),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 200,
                  width: 200,
                  child: Gif(
                    image: AssetImage(Assets.animations.successTick.path),
                    autostart: Autostart.once,
                    height: 200,
                    width: 200,
                  ),
                ),
                const Gap(8),
                Text(context.loc.spSent, style: context.font.headlineLarge),
                const Gap(24),
                if (txid.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AddressViewer(txid, textAlign: TextAlign.center),
                  ),
                const Gap(40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: BBButton.big(
                    label: context.loc.doneButton,
                    onPressed: done,
                    bgColor: context.appColors.secondary,
                    textColor: context.appColors.onSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
