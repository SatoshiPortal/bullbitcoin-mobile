import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullButtonSize,
        BullLabeledTextInput,
        BullThemeX,
        BullTypographyX,
        Gap;
import 'package:silent/src/presentation/silent_l10n.dart';
import 'package:silent/src/presentation/sp_connection_status.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/presentation/sp_failure_l10n.dart';
import 'package:material_ui/material_ui.dart';

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
  final SilentFailure? testError;
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
              child: BullLabeledTextInput(
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
            BullButton.secondary(
              size: BullButtonSize.small,
              compact: true,
              label: context.silentLoc.silentTestButton,
              onPressed: (!editable || controller.text.isEmpty) ? null : onTest,
              textStyle: context.bullType.caption,
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
  final SilentFailure? testError;

  @override
  Widget build(BuildContext context) {
    switch (test) {
      case SpConnectionStatus.untested:
        return const SizedBox(height: 4);
      case SpConnectionStatus.testing:
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            context.silentLoc.silentTestingConnection,
            style: context.bullType.label
                .copyWith(fontWeight: FontWeight.w400)
                .copyWith(color: context.bull.outline),
          ),
        );
      case SpConnectionStatus.ok:
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            children: [
              Icon(Icons.check_circle, size: 14, color: context.bull.success),
              const Gap(4),
              Text(
                context.silentLoc.silentConnected,
                style: context.bullType.label
                    .copyWith(fontWeight: FontWeight.w400)
                    .copyWith(color: context.bull.success),
              ),
            ],
          ),
        );
      case SpConnectionStatus.failed:
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            testError?.toTranslated(context) ??
                context.silentLoc.silentConnectionFailed,
            style: context.bullType.label
                .copyWith(fontWeight: FontWeight.w400)
                .copyWith(color: context.bull.error),
          ),
        );
    }
  }
}
