import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ConsolidationRequiredCard extends StatefulWidget {
  const ConsolidationRequiredCard({
    super.key,
    required this.title,
    this.onTap,
    this.body,
  });

  final Future<void> Function()? onTap;
  final String title;
  final String? body;

  @override
  State<ConsolidationRequiredCard> createState() =>
      _ConsolidationRequiredCardState();
}

class _ConsolidationRequiredCardState extends State<ConsolidationRequiredCard> {
  bool _navigating = false;

  Future<void> _handleTap(Future<void> Function() onTap) async {
    setState(() => _navigating = true);
    try {
      await onTap();
    } catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: st,
          library: 'ConsolidationRequiredCard',
          context: ErrorDescription('while handling the card tap'),
        ),
      );
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    return InkWell(
      onTap: onTap == null || _navigating ? null : () => _handleTap(onTap),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appColors.surfaceContainer,
          border: Border.all(
            color: context.appColors.surfaceContainerHighest,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: context.appColors.error, size: 24),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BBText(
                    widget.title,
                    style: context.font.bodyMedium,
                    color: context.appColors.onSurface,
                  ),
                  if (widget.body != null) ...[
                    const Gap(2),
                    BBText(
                      widget.body!,
                      style: context.font.bodyMedium,
                      color: context.appColors.secondary,
                      maxLines: 4,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
