import 'package:bull_ui/bull_ui.dart' show BullAlertCard, BullSizes;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:send/src/consolidation/domain/consolidation.dart';
import 'package:send/src/consolidation/presentation/consolidation_banner_cubit.dart';
import 'package:send/src/consolidation/ui/consolidation_router.dart';
import 'package:send/src/send_localizations.dart';

class ConsolidationBanner extends StatelessWidget {
  const ConsolidationBanner({
    super.key,
    required this.consolidation,
    required this.walletId,
    required this.isRefreshing,
    this.walletName,
  });

  final Consolidation consolidation;
  final String walletId;
  final bool isRefreshing;
  final String? walletName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: ValueKey(walletId),
      create: (_) => ConsolidationBannerCubit(
        consolidation: consolidation,
        walletId: walletId,
      )..reload(),
      child: _ConsolidationBannerView(
        walletId: walletId,
        walletName: walletName,
        isRefreshing: isRefreshing,
      ),
    );
  }
}

class _ConsolidationBannerView extends StatefulWidget {
  const _ConsolidationBannerView({
    required this.walletId,
    required this.walletName,
    required this.isRefreshing,
  });

  final String walletId;
  final String? walletName;
  final bool isRefreshing;

  @override
  State<_ConsolidationBannerView> createState() =>
      _ConsolidationBannerViewState();
}

class _ConsolidationBannerViewState extends State<_ConsolidationBannerView> {
  @override
  void didUpdateWidget(_ConsolidationBannerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRefreshing && !widget.isRefreshing) {
      context.read<ConsolidationBannerCubit>().reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConsolidationBannerCubit, bool>(
      builder: (context, required) {
        if (!required) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, BullSizes.homeCardGap, 16, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: BullSizes.homeCard),
            child: BullAlertCard(
              title: switch (widget.walletName) {
                final name? => context.loc.consolidationRequiredTitleNamed(
                  name,
                ),
                null => context.loc.consolidationRequiredTitle,
              },
              onTap: () => context.pushNamed(
                ConsolidationRoute.consolidation.name,
                pathParameters: {'walletId': widget.walletId},
              ),
            ),
          ),
        );
      },
    );
  }
}
