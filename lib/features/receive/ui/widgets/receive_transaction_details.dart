import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

class ReceiveTransactionDetails extends StatelessWidget {
  const ReceiveTransactionDetails({
    super.key,
    required this.items,
  });

  final List<ReceiveTransactionDetailsItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.onPrimary,
        border: Border.all(
          color: theme.colorScheme.surface,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i != items.length - 1)
              Divider(
                color: theme.colorScheme.secondaryFixedDim,
              ),
          ],
        ],
      ),
    );
  }
}

class ReceiveTransactionDetailsItem extends StatelessWidget {
  const ReceiveTransactionDetailsItem({
    super.key,
    required this.label,
    required this.displayValue,
    this.copyValue,
    this.isUnderline = false,
  });

  final String label;
  final String displayValue;
  final String? copyValue;
  final bool isUnderline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Label
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.surfaceContainer,
              ),
            ),
          ),

          // Value + copy icon
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    displayValue,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.clip,
                    maxLines: 1,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.outlineVariant,
                      decoration: isUnderline
                          ? TextDecoration.underline
                          : TextDecoration.none,
                    ),
                  ),
                ),
                const Gap(8),
                if (copyValue != null && copyValue!.isNotEmpty)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      splashColor: theme.colorScheme.primary.withValues(
                        alpha: 30,
                      ),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: copyValue!));
                      },
                      child: Icon(
                        Icons.copy_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
