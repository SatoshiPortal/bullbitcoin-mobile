import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:flutter/material.dart';

class ErrorReportingStep extends StatelessWidget {
  const ErrorReportingStep({
    super.key,
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final shape = StadiumBorder(side: BorderSide(color: outline));
    return Column(
      children: [
        Text(
          context.loc.errorReportingProgramDescription,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: enabled,
          onChanged: onChanged,
          shape: shape,
          title: Text(
            enabled
                ? context.loc.errorReportingIContribute
                : context.loc.errorReportingIDoNotContribute,
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: true,
          // The callback fires but `value` is hardcoded true, so the switch
          // never visually flips. Tapping surfaces the snackbar instead.
          onChanged: (_) => SnackBarUtils.showSnackBar(
            context,
            context.loc.errorReportingMigrationSnackbar,
          ),
          shape: shape,
          title: Text(context.loc.errorReportingMigrationTitle),
        ),
      ],
    );
  }
}
