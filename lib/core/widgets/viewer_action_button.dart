import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Standard action row used inside address / transaction / invoice detail
/// dialogs (Copy, Copy link, Open in explorer).
///
/// Wraps icon + label in an [InkWell] with a 44dp minimum touch target so
/// taps land reliably; the previous bare [Row] gave a ~14dp hit zone.
class ViewerActionButton extends StatelessWidget {
  const ViewerActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: context.appColors.primary),
              const Gap(4),
              BBText(
                label,
                style: context.font.bodySmall,
                color: context.appColors.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
