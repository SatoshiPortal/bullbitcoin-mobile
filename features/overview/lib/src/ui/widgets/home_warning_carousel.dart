import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullCarousel, BullInfoCard, BullSizes, Gap;
import 'package:material_ui/material_ui.dart';

enum HomeWarningDestination { electrum, tor, swap }

typedef HomeWarningCopy = ({String title, String description});
typedef HomeNetworkWarning = ({
  HomeWarningCopy copy,
  HomeWarningDestination destination,
});

class HomeWarningCarousel extends StatelessWidget {
  final List<HomeNetworkWarning> network;
  final HomeWarningCopy? swap;
  final HomeWarningCopy? load;
  final Widget? backup;
  final ValueChanged<HomeWarningDestination> onOpen;

  const HomeWarningCarousel({
    super.key,
    required this.network,
    required this.swap,
    required this.load,
    required this.backup,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final warning in network)
        _card(context, warning.copy, warning.destination),
      if (swap case final warning?)
        _card(context, warning, HomeWarningDestination.swap),
      if (load case final warning?) _card(context, warning),
    ];
    if (cards.isEmpty && backup == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(
        left: 13,
        right: 13,
        top: BullSizes.homeCardGap,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (cards.isNotEmpty) BullCarousel(children: cards),
          if (backup case final card?) ...[
            if (cards.isNotEmpty) const Gap(BullSizes.homeCardGap),
            card,
          ],
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context,
    HomeWarningCopy copy, [
    HomeWarningDestination? destination,
  ]) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: BullSizes.homeCard),
    child: BullInfoCard(
      title: copy.title,
      description: copy.description,
      tagColor: context.appColors.error,
      bgColor: context.appColors.errorContainer,
      onTap: destination == null ? null : () => onOpen(destination),
    ),
  );
}
