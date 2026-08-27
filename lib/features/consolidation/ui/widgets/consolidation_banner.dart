import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/cards/consolidation_required_card.dart';
import 'package:bb_mobile/features/consolidation/presentation/consolidation_banner_cubit.dart';
import 'package:bb_mobile/features/consolidation/ui/consolidation_router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ConsolidationBanner extends StatelessWidget {
  const ConsolidationBanner({
    super.key,
    required this.wallet,
    this.showWalletName = false,
  });

  final Wallet wallet;
  final bool showWalletName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          locator<ConsolidationBannerCubit>(param1: wallet.id)..reload(),
      child: _ConsolidationBannerView(
        wallet: wallet,
        showWalletName: showWalletName,
      ),
    );
  }
}

class _ConsolidationBannerView extends StatelessWidget {
  const _ConsolidationBannerView({
    required this.wallet,
    required this.showWalletName,
  });

  final Wallet wallet;
  final bool showWalletName;

  @override
  Widget build(BuildContext context) {
    return BlocListener<WalletBloc, WalletState>(
      // Re-check after a sync finishes (a received tx may push it over).
      listenWhen: (prev, curr) => prev.isRefreshing && !curr.isRefreshing,
      listener: (context, _) =>
          context.read<ConsolidationBannerCubit>().reload(),
      child: BlocBuilder<ConsolidationBannerCubit, bool>(
        builder: (context, required) {
          if (!required) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ConsolidationRequiredCard(
              title: showWalletName
                  ? context.loc.consolidationRequiredTitleNamed(
                      wallet.displayLabel(context),
                    )
                  : context.loc.consolidationRequiredTitle,
              onTap: () => context.pushNamed(
                ConsolidationRoute.consolidation.name,
                pathParameters: {'walletId': wallet.id},
              ),
            ),
          );
        },
      ),
    );
  }
}

class HomeConsolidationBanner extends StatelessWidget {
  const HomeConsolidationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final liquidWallets = context.select<WalletBloc, List<Wallet>>(
      (bloc) => bloc.state.wallets.where((w) => w.isLiquid).toList(),
    );
    if (liquidWallets.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final wallet in liquidWallets)
          ConsolidationBanner(wallet: wallet, showWalletName: true),
      ],
    );
  }
}
