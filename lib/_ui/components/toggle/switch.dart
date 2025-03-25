import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:flutter/material.dart';

class BBSwitch extends StatelessWidget {
  const BBSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(
      inactiveTrackColor: context.colour.surface,
      trackOutlineWidth: const WidgetStatePropertyAll(0),
      inactiveThumbColor: context.colour.onPrimary,
      padding: EdgeInsets.zero,
      value: value,
      thumbIcon: WidgetStatePropertyAll(
        Icon(
          Icons.circle,
          color: context.colour.onPrimary,
        ),
      ),
      onChanged: onChanged,
    );
  }
}
