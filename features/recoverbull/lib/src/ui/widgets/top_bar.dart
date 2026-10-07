import 'package:bull_ui/bull_ui.dart';
import 'with_bull_theme.dart';

class TopBar extends StatelessWidget {
  final VoidCallback onBack;
  final Object title;

  const TopBar({super.key, required this.onBack, required this.title});

  @override
  Widget build(BuildContext context) => withBullTheme(
    context,
    BullTopBar(
      title: title is Text ? (title as Text).data ?? '' : title.toString(),
      onBack: onBack,
    ),
  );
}
