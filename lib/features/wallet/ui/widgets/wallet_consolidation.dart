import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:send/send.dart';

/// Wallet presentation inputs for the consolidation review and banners.
abstract final class WalletConsolidation {
  static int? selectBalanceSat(BuildContext context, String walletId) =>
      context.select((WalletBloc bloc) {
        for (final wallet in bloc.state.wallets) {
          if (wallet.id == walletId) return wallet.balanceSat?.toInt();
        }
        return null;
      });

  static Widget banner(
    BuildContext context,
    Wallet wallet, {
    bool showWalletName = false,
  }) => ConsolidationBanner(
    consolidation: context.read<Consolidation>(),
    walletId: wallet.id,
    isRefreshing: context.select((WalletBloc bloc) => bloc.state.isRefreshing),
    walletName: showWalletName ? wallet.displayLabel(context) : null,
  );
}

class HomeConsolidationBanner extends StatelessWidget {
  const HomeConsolidationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final liquidWallets = context.select<WalletBloc, List<Wallet>>(
      (bloc) => bloc.state.wallets.where((wallet) => wallet.isLiquid).toList(),
    );
    if (liquidWallets.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final wallet in liquidWallets)
          WalletConsolidation.banner(context, wallet, showWalletName: true),
      ],
    );
  }
}
