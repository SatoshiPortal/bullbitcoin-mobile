import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/labeled_text_input.dart';
import 'package:bb_mobile/features/sp/presentation/sp_connection_status.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/presentation/sp_failure_l10n.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

/// A backend (blindbit/electrum) URL field with an inline "Test connection"
/// button and a status line. The connection status doubles as the field's
/// connection state in settings.
class SpBackendUrlField extends StatelessWidget {
  const SpBackendUrlField({
    super.key,
    required this.label,
    required this.controller,
    required this.onChanged,
    required this.test,
    required this.testError,
    required this.onTest,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final SpConnectionStatus test;
  final SpFailure? testError;
  final VoidCallback onTest;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // The status line says when a test is running, so the button only dims.
    final editable = enabled && test != SpConnectionStatus.testing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: LabeledTextInput(
                label: label,
                controller: controller,
                value: controller.text,
                // A URL is one line: left unbounded the field grows a line at
                // a time as the URL gets longer, next to the Test button.
                maxLines: 1,
                onChanged: editable ? onChanged : null,
              ),
            ),
            const Gap(8),
            BBButton.small(
              compact: true,
              label: context.loc.spTestButton,
              onPressed: onTest,
              disabled: !editable || controller.text.isEmpty,
              bgColor: context.appColors.transparent,
              textColor: context.appColors.secondary,
              textStyle: context.font.labelMedium,
              outlined: true,
            ),
          ],
        ),
        _StatusLine(test: test, testError: testError),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.test, required this.testError});
  final SpConnectionStatus test;
  final SpFailure? testError;

  @override
  Widget build(BuildContext context) {
    switch (test) {
      case SpConnectionStatus.untested:
        return const SizedBox(height: 4);
      case SpConnectionStatus.testing:
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            context.loc.spTestingConnection,
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.outline,
            ),
          ),
        );
      case SpConnectionStatus.ok:
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                size: 14,
                color: context.appColors.success,
              ),
              const Gap(4),
              Text(
                context.loc.spConnected,
                style: context.font.bodySmall?.copyWith(
                  color: context.appColors.success,
                ),
              ),
            ],
          ),
        );
      case SpConnectionStatus.failed:
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            testError?.toTranslated(context) ?? context.loc.spConnectionFailed,
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.error,
            ),
          ),
        );
    }
  }
}
