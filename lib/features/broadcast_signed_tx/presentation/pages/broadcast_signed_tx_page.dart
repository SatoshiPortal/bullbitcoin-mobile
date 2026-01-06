import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/paste_input.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/transaction_details_widget.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_state.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:gif/gif.dart';
import 'package:go_router/go_router.dart';

class BroadcastSignedTxPage extends StatelessWidget {
  const BroadcastSignedTxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.broadcastSignedTxPageTitle,
          onBack: () => context.pop(),
        ),
      ),
      body: BlocBuilder<BroadcastSignedTxCubit, BroadcastSignedTxState>(
        builder: (context, state) {
          final cubit = context.read<BroadcastSignedTxCubit>();

          return SingleChildScrollView(
            child: Column(
              children: [
                if (state.transaction == null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: PasteInput(
                      text: state.transaction?.data ?? '',
                      hint: context.loc.broadcastSignedTxPasteHint,
                      onChanged: cubit.tryParseTransaction,
                    ),
                  ),
                  if (state.error != null) ...[
                    const Gap(16),
                    BBText(
                      state.error.toString(),
                      style: context.font.bodyMedium,
                      color: context.appColors.error,
                    ),
                  ],

                  const Gap(16),
                  BBButton.small(
                    label: context.loc.broadcastSignedTxCameraButton,
                    onPressed: () {
                      cubit.resetState();
                      context.pushNamed(
                        BroadcastSignedTxRoute.broadcastScanQr.name,
                      );
                    },
                    bgColor: context.appColors.surface,
                    textColor: context.appColors.text,
                    iconData: Icons.qr_code_scanner,
                    outlined: true,
                  ),
                  const Gap(32),
                  BBButton.small(
                    label: context.loc.broadcastSignedTxPushTxButton,
                    onPressed:
                        () => context.pushNamed(
                          BroadcastSignedTxRoute.broadcastScanNfc.name,
                        ),
                    bgColor: context.appColors.surface,
                    textColor: context.appColors.text,
                    iconData: Icons.nfc,
                    outlined: true,
                  ),
                ],

                // Broadcast button
                if (state.transaction != null &&
                    state.isBroadcasted == false) ...[
                  TransactionDetailsWidget(tx: state.transaction!.tx),
                ],

                if (state.transaction != null)
                  Row(
                    children: [
                      if (state.pushTxUri != null &&
                          state.isBroadcasted == false)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: BBButton.big(
                              label: context.loc.broadcastSignedTxPushTxButton,
                              bgColor: context.appColors.primary,
                              textColor: context.appColors.onPrimary,
                              onPressed: cubit.pushTxUri,
                            ),
                          ),
                        ),

                      if (state.isBroadcasted == false)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: BBButton.big(
                              label: context.loc.broadcastSignedTxBroadcast,
                              bgColor: context.appColors.primary,
                              textColor: context.appColors.onPrimary,
                              onPressed: cubit.broadcastTransaction,
                            ),
                          ),
                        ),
                    ],
                  ),

                if (state.isBroadcasted == true) ...[
                  Gif(
                    image: AssetImage(Assets.animations.successTick.path),
                    autostart: Autostart.once,
                    height: 200,
                    width: 200,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 100, right: 100),
                    child: BBButton.big(
                      label: context.loc.broadcastSignedTxDoneButton,
                      bgColor: context.appColors.primary,
                      textColor: context.appColors.onPrimary,
                      onPressed:
                          () => context.goNamed(WalletRoute.walletHome.name),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
