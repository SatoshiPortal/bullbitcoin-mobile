import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class LegacyStorageStepRow extends StatelessWidget {
  const LegacyStorageStepRow({
    super.key,
    required this.index,
    required this.label,
    this.done = false,
  });

  final int index;
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Bullet(index: index, done: done),
          const Gap(12),
          Expanded(
            child: BBText(
              label,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.index, required this.done});

  final int index;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = done ? context.appColors.success : context.appColors.primary;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: done
          ? Icon(Icons.check, size: 14, color: context.appColors.onPrimary)
          : BBText(
              '$index',
              style: context.font.labelSmall?.copyWith(
                color: context.appColors.onPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
    );
  }
}
