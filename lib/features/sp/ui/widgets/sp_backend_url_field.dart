import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/sp/presentation/sp_conn_test.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/presentation/sp_failure_l10n.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

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
  final SpConnTest test;
  final SpFailure? testError;
  final VoidCallback onTest;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final testing = test == SpConnTest.testing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                enabled: enabled && !testing,
                decoration: InputDecoration(labelText: label),
                onChanged: onChanged,
              ),
            ),
            const Gap(8),
            TextButton(
              onPressed: (enabled && !testing && controller.text.isNotEmpty)
                  ? onTest
                  : null,
              child: testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.loc.spTestButton),
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
  final SpConnTest test;
  final SpFailure? testError;

  @override
  Widget build(BuildContext context) {
    switch (test) {
      case SpConnTest.untested:
        return const SizedBox(height: 4);
      case SpConnTest.testing:
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            context.loc.spTestingConnection,
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.outline,
            ),
          ),
        );
      case SpConnTest.ok:
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
      case SpConnTest.failed:
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
