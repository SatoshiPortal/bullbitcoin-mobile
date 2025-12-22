import 'package:bb_mobile/core/mempool/application/dtos/mempool_server_dto.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

class MempoolServerItem extends StatelessWidget {
  const MempoolServerItem({
    super.key,
    required this.server,
    this.isCustom = false,
    this.disabled = false,
    this.useForFeeEstimation = true,
    this.isProcessing = false,
    this.onFeeEstimationChanged,
    this.onDelete,
    this.onEdit,
  });

  final MempoolServerDto server;
  final bool isCustom;
  final bool disabled;
  final bool useForFeeEstimation;
  final bool isProcessing;
  final ValueChanged<bool>? onFeeEstimationChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.appColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: disabled
                ? context.appColors.border.withValues(alpha: 0.5)
                : context.appColors.border,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              server.url,
                              style: context.font.bodyMedium?.copyWith(
                                color: context.appColors.onSurface,
                                decoration: disabled
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                            ),
                          ),
                          if (isCustom) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.appColors.tertiaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                context.loc.mempoolCustomServerLabel,
                                style: context.font.bodySmall?.copyWith(
                                  color: context.appColors.tertiary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        server.fullUrl,
                        style: context.font.bodySmall?.copyWith(
                          color: context.appColors.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      if (disabled) ...[
                        const SizedBox(height: 4),
                        Text(
                          context.loc.mempoolServerNotUsed,
                          style: context.font.bodySmall?.copyWith(
                            color: context.appColors.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isCustom && onEdit != null) ...[
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      color: context.appColors.primary,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: isProcessing ? null : onEdit,
                  ),
                ],
                if (isCustom && onDelete != null) ...[
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: context.appColors.error,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: isProcessing ? null : onDelete,
                  ),
                ],
              ],
            ),
            if (!disabled && onFeeEstimationChanged != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.loc.mempoolSettingsUseForFeeEstimation,
                      style: context.font.bodySmall?.copyWith(
                        color: context.appColors.onSurface,
                      ),
                    ),
                  ),
                  Switch(
                    value: useForFeeEstimation,
                    onChanged: isProcessing ? null : onFeeEstimationChanged,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
