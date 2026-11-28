import 'package:material_ui/material_ui.dart';
import 'package:send/src/consolidation/domain/consolidation.dart';
import 'package:send/src/consolidation/ui/widgets/consolidation_banner.dart';

/// Consolidation warnings for the Liquid wallets shown on the home screen.
///
/// The caller supplies the current Liquid wallets and their display labels.
class HomeConsolidationBanner extends StatelessWidget {
  const HomeConsolidationBanner({
    super.key,
    required this.consolidation,
    required this.wallets,
    required this.isRefreshing,
  });

  final Consolidation consolidation;
  final List<({String walletId, String walletName})> wallets;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    if (wallets.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final wallet in wallets)
          ConsolidationBanner(
            consolidation: consolidation,
            walletId: wallet.walletId,
            walletName: wallet.walletName,
            isRefreshing: isRefreshing,
          ),
      ],
    );
  }
}
