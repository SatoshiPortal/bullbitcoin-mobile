import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/cards/consolidation_required_card.dart';
import 'package:bb_mobile/features/consolidation/presentation/consolidation_banner_cubit.dart';
import 'package:bb_mobile/features/consolidation/ui/consolidation_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ConsolidationBanner extends StatefulWidget {
  const ConsolidationBanner({
    super.key,
    required this.wallet,
    this.showWalletName = false,
    this.isRefreshing = false,
  });

  final Wallet wallet;
  final bool showWalletName;

  final bool isRefreshing;
  @override
  State<ConsolidationBanner> createState() => _ConsolidationBannerState();
}

class _ConsolidationBannerState extends State<ConsolidationBanner> {
  late final ConsolidationBannerCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = locator<ConsolidationBannerCubit>(param1: widget.wallet.id)
      ..reload();
  }

  @override
  void didUpdateWidget(covariant ConsolidationBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRefreshing && !widget.isRefreshing) {
      _cubit.reload();
    }
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConsolidationBannerCubit, bool>(
      bloc: _cubit,
      builder: (context, required) {
        if (!required) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: ConsolidationRequiredCard(
            title: widget.showWalletName
                ? context.loc.consolidationRequiredTitleNamed(
                    widget.wallet.displayLabel(context),
                  )
                : context.loc.consolidationRequiredTitle,
            onTap: () => context.pushNamed(
              ConsolidationRoute.consolidation.name,
              pathParameters: {'walletId': widget.wallet.id},
            ),
          ),
        );
      },
    );
  }
}

class HomeConsolidationBanner extends StatelessWidget {
  const HomeConsolidationBanner({
    super.key,
    required this.liquidWallets,
    this.isRefreshing = false,
  });

  final List<Wallet> liquidWallets;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    if (liquidWallets.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final wallet in liquidWallets)
          ConsolidationBanner(
            wallet: wallet,
            showWalletName: true,
            isRefreshing: isRefreshing,
          ),
      ],
    );
  }
}
