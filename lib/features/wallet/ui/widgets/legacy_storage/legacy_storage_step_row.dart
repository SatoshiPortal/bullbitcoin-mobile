import 'package:bull_ui/bull_ui.dart';

class LegacyStorageStepRow extends StatelessWidget {
  const LegacyStorageStepRow({
    super.key,
    required this.index,
    required this.label,
  });

  final int index;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Bullet(index: index),
          const Gap(12),
          Expanded(
            child: BullText(
              label,
              style: context.bullText.bodyMedium?.copyWith(
                color: context.bull.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: context.bull.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: BullText(
        '$index',
        style: context.bullText.labelSmall?.copyWith(
          color: context.bull.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
