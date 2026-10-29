import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart' as btc_utils;
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/transaction_review_cubit.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/ui/transaction_review_view.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/nfc_bottom_sheet.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/broadcast_signed_tx_failure.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_failure_l10n.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_state.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullPasteInput,
        BullText,
        BullTopBar,
        BullSelectableList,
        BullSelectableListItem,
        BullShimmerLine,
        Gap;
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
        flexibleSpace: BullTopBar(
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
                  state.transaction != null &&
                  state.sourceWallet != null &&
                  !state.isBroadcasted;
              if (!showActions) return const SizedBox.shrink();
              return const SafeArea(child: _BroadcastActions());
            },
          ),
      body: BlocBuilder<BroadcastSignedTxCubit, BroadcastSignedTxState>(
        builder: (context, state) {
          final cubit = context.read<BroadcastSignedTxCubit>();
          final transaction = state.transaction;
          final sourceWallet = state.sourceWallet;

          return SingleChildScrollView(
            child: Column(
              children: [
                if (transaction == null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: BullPasteInput(
                      text: state.transaction?.data ?? '',
                      hint: context.loc.broadcastSignedTxPasteHint,
                      onChanged: cubit.tryParseTransaction,
                    ),
                  ),
                  if (state.failure != null) ...[
                    const Gap(16),
                    BullText(
                      state.failure!.toTranslated(context),
                      style: context.font.bodyMedium,
                      color: context.appColors.error,
                    ),
                  ],

                  const Gap(16),
                  BullButton.small(
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
                  BullButton.small(
                    label: context.loc.broadcastSignedTxNfcButton,
                    onPressed: () => NfcBottomSheet.showReadNfc(
                      context: context,
                      title: context.loc.broadcastSignedTxColdcardNfcSheetTitle,
                      onDataReceived: (payload) => cubit.onQrScanned(payload),
                    ),
                    bgColor: context.appColors.surface,
                    textColor: context.appColors.text,
                    iconData: Icons.nfc,
                    outlined: true,
                  ),
                  const Gap(32),
                  BullButton.small(
                    label: context.loc.broadcastSignedTxPushTxButton,
                    onPressed: () => context.pushNamed(
                      BroadcastSignedTxRoute.broadcastScanNfc.name,
                    ),
                    bgColor: context.appColors.surface,
                    textColor: context.appColors.text,
                    iconData: Icons.contactless_outlined,
                    outlined: true,
                  ),
                ],

                if (transaction != null && !state.isBroadcasted) ...[
                  BullText(
                    context.loc.syncSelectSourceWallet,
                    style: context.font.bodyMedium,
                  ),
                  if (state.loadingWallets) const BullShimmerLine(),
                  if (state.failure case final failure?)
                    _BroadcastError(failure: failure),
                  if (!state.loadingWallets && state.wallets.isEmpty)
                    BullButton.big(
                      label: context.loc.retry,
                      onPressed: cubit.loadWallets,
                      bgColor: context.appColors.primary,
                      textColor: context.appColors.onPrimary,
                    ),
                  BullSelectableList(
                    selectedValue: state.sourceWallet?.id ?? '',
                    onChanged: cubit.selectSourceWallet,
                    items: [
                      for (final wallet in state.wallets)
                        BullSelectableListItem(
                          title: wallet.displayLabel(context),
                          subtitle1:
                              wallet.bitcoinSyncSource ==
                                  BitcoinSyncSource.compactBlockFilters
                              ? context.loc.syncPrivateTitle
                              : context.loc.syncFastTitle,
                          subtitle2: '',
                          value: wallet.id,
                        ),
                    ],
                  ),
                ],
                // Transaction review using TransactionReviewView
                if (transaction != null &&
                    sourceWallet != null &&
                    state.isBroadcasted == false) ...[
                  BlocProvider(
                    key: _SourceWalletKey(state.sourceWallet?.id ?? ''),
                    create: (_) => locator<TransactionReviewCubit>(),
                    child: _TransactionReviewSection(
                      bitcoinTx: transaction.tx,
                      wallet: sourceWallet,
                    ),
                  ),
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
                    child: BullButton.big(
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
    final isBroadcasting = context.select(
      (BroadcastSignedTxCubit c) => c.state.isBroadcasting,
    );

    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: BullButton.big(
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
  const _BroadcastError({required this.failure});

  final BroadcastSignedTxFailure failure;

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
            child: BullText(
              failure.toTranslated(context),
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
  const _TransactionReviewSection({
    required this.bitcoinTx,
    required this.wallet,
  });

  final btc_utils.BitcoinTx bitcoinTx;
  final Wallet wallet;

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
      walletId: widget.wallet.id,
      source: widget.wallet.bitcoinSyncSource,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Actions are rendered in the page's bottomNavigationBar (pinned), not
    // here, so they don't shift with the scroll content.
    return TransactionReviewView(
      fromLabel: widget.wallet.displayLabel(context),
    );
  }
}

class _SourceWalletKey extends ValueKey<String> {
  const _SourceWalletKey(super.value);
  @override
  String toString() => 'BroadcastSourceWalletKey';
}
