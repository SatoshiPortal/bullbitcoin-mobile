import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullCarousel, BullInfoCard, BullSizes;
import 'package:material_ui/material_ui.dart';

enum HomeWarningDestination { electrum, tor, swap }

typedef HomeWarningCopy = ({String title, String description});
typedef HomeNetworkWarning = ({
  HomeWarningCopy copy,
  HomeWarningDestination destination,
});

/// Home's notices, one at a time and swipeable, in priority order: service
/// errors, swaps in progress, then the backup reminder.
class HomeWarningCarousel extends StatelessWidget {
  final List<HomeNetworkWarning> network;
  final HomeWarningCopy? swap;
  final HomeWarningCopy? load;
  final List<Widget> swaps;
  final Widget? backup;
  final ValueChanged<HomeWarningDestination> onOpen;

  const HomeWarningCarousel({
    super.key,
    required this.network,
    required this.swap,
    required this.load,
    this.swaps = const [],
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
      for (final notice in swaps) _sized(notice),
      if (backup case final card?) _sized(card),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(
        left: 13,
        right: 13,
        top: BullSizes.homeCardGap,
      ),
      child: BullCarousel(children: cards),
    );
  }

  Widget _sized(Widget card) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: BullSizes.homeCard),
    child: card,
  );

  Widget _card(
    BuildContext context,
    HomeWarningCopy copy, [
    HomeWarningDestination? destination,
  ]) => _sized(
    BullInfoCard(
      title: copy.title,
      description: copy.description,
      tagColor: context.appColors.error,
      bgColor: context.appColors.errorContainer,
      onTap: destination == null ? null : () => onOpen(destination),
    ),
  );
}
