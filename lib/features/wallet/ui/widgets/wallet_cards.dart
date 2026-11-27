import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:overview/overview.dart';
import 'package:silent/silent.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sync/sync.dart' show WalletKey;

class WalletCards extends StatelessWidget {
  const WalletCards({
    super.key,
    this.padding,
    this.onTap,
    this.localSignersOnly = false,
  });

  final EdgeInsetsGeometry? padding;
  final bool localSignersOnly;
  final Function(Wallet wallet)? onTap;

  static Widget pickLocalSigner(
    BuildContext context,
    ValueChanged<({WalletKey key, String? label, bool isDefault})>? onSelected,
  ) => WalletCards(
    padding: EdgeInsets.zero,
    localSignersOnly: true,
    onTap: onSelected == null
        ? null
        : (wallet) => onSelected((
            key: WalletKey(id: wallet.id, network: wallet.network.shared),
            label: wallet.label,
            isDefault: wallet.isDefault,
          )),
  );

  static Color cardDetails(BuildContext context, Wallet wallet) {
    final isTestnet = !wallet.network.isMainnet;
    final isLiquid = wallet.isLiquid;
    final watchOrSignsRemotely = wallet.isWatchOnly || wallet.signsRemotely;

    final watchonlyColor = context.appColors.secondary;

    if (watchOrSignsRemotely && !isTestnet) return watchonlyColor;
    if (watchOrSignsRemotely && isTestnet) return watchonlyColor;

    if (isLiquid) return context.appColors.tertiary;

    if (isTestnet) return context.appColors.onTertiary;
    return context.appColors.onTertiary;
  }

  @override
  Widget build(BuildContext context) {
    final wallets = context.select(
      (WalletBloc bloc) => localSignersOnly
          ? bloc.state.wallets.where((w) => w.signsLocally)
          : bloc.state.wallets,
    );
    final syncStatus = context.select(
      (WalletBloc bloc) => bloc.state.syncStatus,
    );

    final spBalanceSat = context.select(
      (WalletBloc bloc) => bloc.state.spBalanceSat,
    );
    // Read the SP feature gate (superuser + dev mode) and setup state from the
    // wallet's own bloc, so this widget doesn't import the settings feature's
    // presentation (rule #1). WalletBloc mirrors the gate into its state.
    final showSpWallet = context.select(
      (WalletBloc bloc) => bloc.state.showSpWallet,
    );
    final isSpWalletLoading = context.select(
      (WalletBloc bloc) => bloc.state.isSpWalletLoading,
    );

    return WalletCardList(
      padding: padding,
      unavailableLabel: context.loc.walletLoadFailed,
      rows: [
        for (final wallet in wallets)
          (
            tagColor: cardDetails(context, wallet),
            title: wallet.displayLabel(context),
            description: switch (WalletCardSubtitle.of(
              wallet.network.shared,
              wallet.signer,
            )) {
              WalletCardSubtitle.externalSigner =>
                context.loc.walletTypeWatchSigner,
              WalletCardSubtitle.watchOnly => context.loc.walletTypeWatchOnly,
              WalletCardSubtitle.bitcoin =>
                context.loc.walletTypeBitcoinNetwork,
              WalletCardSubtitle.liquidAndLightning =>
                context.loc.walletTypeLiquidAndLightning,
            },
            balanceSat: wallet.balanceSat?.toInt(),
            // The existing producer reports progress by ID, not WalletKey.
            isSyncing: syncStatus[wallet.id] ?? false,
            onTap: () => onTap?.call(wallet),
          ),
      ],
      silent: showSpWallet
          ? (
              tagColor: context.appColors.tertiary,
              title: context.loc.walletSpTitle,
              description: context.loc.walletSpExperimental,
              balanceSat: spBalanceSat,
              isSyncing: isSpWalletLoading,
              onTap: () => SilentNavigation.openWallet(context),
            )
          : null,
    );
  }
}
