import 'package:bull_ui/bull_ui.dart';

class LegacyStorageBadge extends StatelessWidget {
  const LegacyStorageBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.bull.primary,
        borderRadius: BorderRadius.circular(2),
      ),
      child: BullText(
        label,
        style: TextStyle(
          fontFamily: 'Bebas Neue',
          color: context.bull.onPrimary,
          fontSize: 14,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
