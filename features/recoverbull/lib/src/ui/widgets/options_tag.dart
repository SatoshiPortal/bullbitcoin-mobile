import 'package:bull_ui/bull_ui.dart';
import 'with_bull_theme.dart';

class OptionsTag extends StatelessWidget {
  final String text;

  const OptionsTag({super.key, required this.text});

  @override
  Widget build(BuildContext context) =>
      withBullTheme(context, BullOptionsTag(text: text));
}
