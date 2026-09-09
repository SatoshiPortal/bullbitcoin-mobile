import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bull_ui/bull_ui.dart' show BullDropdown;
import 'package:flutter/material.dart';

class SignerDeviceDropdown extends StatelessWidget {
  final SignerDeviceEntity? value;
  final String unknownLabel;
  final ValueChanged<SignerDeviceEntity?>? onChanged;

  const SignerDeviceDropdown({
    super.key,
    required this.value,
    required this.unknownLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BullDropdown<SignerDeviceEntity?>(
      key: ValueKey(value?.name),
      value: value,
      items: [null, ...SignerDeviceEntity.values]
          .map(
            (device) => DropdownMenuItem<SignerDeviceEntity?>(
              value: device,
              child: BBText(
                device?.displayName ?? unknownLabel,
                style: context.font.headlineSmall,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
