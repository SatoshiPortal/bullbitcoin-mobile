import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:flutter/material.dart';

class BuyConfirmDetailRow extends StatelessWidget {
  /// Typographic placeholder, not prose: nothing to translate.
  static const _noValue = '—';

  final String label;
  final String? value;

  /// Whether a missing [value] is never coming.
  ///
  /// A null [value] alone means "still loading" and shimmers. Once the read
  /// behind it has failed, the shimmer would keep asking the user to wait
  /// while the screen tells them it failed, so the row goes quiet instead.
  final bool isUnavailable;

  const BuyConfirmDetailRow({
    super.key,
    required this.label,
    this.value,
    this.isUnavailable = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: .spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.appColors.onSurfaceVariant,
            ),
          ),

          Expanded(
            child: switch ((value, isUnavailable)) {
              (final String value, _) => Text(
                value,
                textAlign: .end,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.appColors.secondary,
                ),
              ),
              (null, true) => Text(
                _noValue,
                textAlign: .end,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.appColors.onSurfaceVariant,
                ),
              ),
              (null, false) => const LoadingLineContent(),
            },
          ),
        ],
      ),
    );
  }
}
