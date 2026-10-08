import 'package:bull_ui/bull_ui.dart';
import 'with_bull_theme.dart';

class InfoCard extends StatelessWidget {
  final String? title;
  final String description;
  final Color tagColor;
  final Color bgColor;
  final VoidCallback? onTap;
  final bool boldDescription;

  const InfoCard({
    super.key,
    this.title,
    required this.description,
    required this.tagColor,
    required this.bgColor,
    this.onTap,
    this.boldDescription = false,
  });

  @override
  Widget build(BuildContext context) => withBullTheme(
    context,
    BullInfoCard(
      title: title,
      description: description,
      tagColor: tagColor,
      bgColor: bgColor,
      onTap: onTap,
      boldDescription: boldDescription,
    ),
  );
}
