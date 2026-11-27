import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:overview/overview.dart';
import 'package:silent/silent.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/presentation/wallet_type_l10n.dart';
import 'package:bull_ui/bull_ui.dart' show BullSizes, Gap;
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

    return Padding(
      padding:
          padding ??
          const EdgeInsets.fromLTRB(
            13,
            BullSizes.homeCardGap,
            13,
            BullSizes.homeCardGap,
          ),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          for (final (index, w) in wallets.indexed) ...[
            if (index > 0) const Gap(BullSizes.homeCardGap),
            if (w.balanceSat case final balance?)
              WalletCard(
                tagColor: cardDetails(context, w),
                title: w.displayLabel(context),
                description: w.typeLabel(context),
                balanceSat: balance.toInt(),
                isSyncing: syncStatus[w.id] ?? false,
                onTap: () => onTap?.call(w),
              )
            else
              ListTile(
                title: Text(w.displayLabel(context)),
                subtitle: Text(context.loc.walletLoadFailed),
                onTap: () => onTap?.call(w),
              ),
          ],
          if (showSpWallet) ...[
            if (wallets.isNotEmpty) const Gap(BullSizes.homeCardGap),
            WalletCard(
              tagColor: context.appColors.tertiary,
              title: context.loc.walletSpTitle,
              description: context.loc.walletSpExperimental,
              balanceSat: spBalanceSat,
              isSyncing: isSpWalletLoading,
              onTap: () => SilentNavigation.openWallet(context),
            ),
          ],
        ],
      ),
    );
  }
}
