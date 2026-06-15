import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart' as btc_utils;
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/transaction_review_cubit.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/ui/transaction_review_view.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/paste_input.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/broadcast_signed_tx_error.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_state.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/locator.dart';
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
      // Actions are pinned to the bottom of the screen (not inline in the
      // scroll content) so they don't jump when the error appears/disappears.
      bottomNavigationBar:
          BlocBuilder<BroadcastSignedTxCubit, BroadcastSignedTxState>(
            builder: (context, state) {
              final showActions =
                  state.transaction != null && !state.isBroadcasted;
              if (!showActions) return const SizedBox.shrink();
              return const SafeArea(child: _BroadcastActions());
            },
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
                      state.error!.toTranslated(context),
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
                    onPressed: () => context.pushNamed(
                      BroadcastSignedTxRoute.broadcastScanNfc.name,
                    ),
                    bgColor: context.appColors.surface,
                    textColor: context.appColors.text,
                    iconData: Icons.nfc,
                    outlined: true,
                  ),
                ],

                // Transaction review using TransactionReviewView
                if (state.transaction != null &&
                    state.isBroadcasted == false) ...[
                  BlocProvider(
                    create: (_) => locator<TransactionReviewCubit>(),
                    child: _TransactionReviewSection(
                      bitcoinTx: state.transaction!.tx,
                    ),
                  ),
                  // Broadcast failure is shown here in the scroll content so
                  // the pinned action buttons stay put when it toggles.
                  if (state.error != null) ...[
                    const Gap(16),
                    _BroadcastError(error: state.error!),
                  ],
                ],

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
                      onPressed: () =>
                          context.goNamed(WalletRoute.walletHome.name),
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

class _BroadcastActions extends StatelessWidget {
  const _BroadcastActions();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BroadcastSignedTxCubit>();
    final pushTxUri = context.select(
      (BroadcastSignedTxCubit c) => c.state.pushTxUri,
    );
    final isBroadcasting = context.select(
      (BroadcastSignedTxCubit c) => c.state.isBroadcasting,
    );

    return Row(
      children: [
        if (pushTxUri != null)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: BBButton.big(
                label: context.loc.broadcastSignedTxPushTxButton,
                bgColor: context.appColors.primary,
                textColor: context.appColors.onPrimary,
                onPressed: cubit.pushTxUri,
                disabled: isBroadcasting,
              ),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: BBButton.big(
              label: context.loc.broadcastSignedTxBroadcast,
              bgColor: context.appColors.primary,
              textColor: context.appColors.onPrimary,
              onPressed: cubit.broadcastTransaction,
              disabled: isBroadcasting,
            ),
          ),
        ),
      ],
    );
  }
}

/// Error block shown in the review screen when a broadcast attempt fails.
/// Renders the localized, user-safe message from the typed error — the
/// underlying server/node reason is logged via `log.warning` (file + console,
/// no Sentry), not leaked to the UI.
class _BroadcastError extends StatelessWidget {
  const _BroadcastError({required this.error});

  final BroadcastSignedTxError error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: context.appColors.error, size: 20),
          const Gap(8),
          Expanded(
            child: BBText(
              error.toTranslated(context),
              style: context.font.bodyMedium,
              color: context.appColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionReviewSection extends StatefulWidget {
  const _TransactionReviewSection({required this.bitcoinTx});

  final btc_utils.BitcoinTx bitcoinTx;

  @override
  State<_TransactionReviewSection> createState() =>
      _TransactionReviewSectionState();
}

class _TransactionReviewSectionState extends State<_TransactionReviewSection> {
  @override
  void initState() {
    super.initState();
    final isTestnet =
        context.read<SettingsCubit>().state.environment?.isTestnet ?? false;
    context.read<TransactionReviewCubit>().loadFromBitcoinTx(
      widget.bitcoinTx,
      isTestnet: isTestnet,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Actions are rendered in the page's bottomNavigationBar (pinned), not
    // here, so they don't shift with the scroll content.
    return const TransactionReviewView();
  }
}
