import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/dropdown/bb_dropdown.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bull_ui/bull_ui.dart' show BullPasteInput, Gap;
import 'package:flutter/material.dart';

final class BullVaultSignerInput extends StatelessWidget {
  static const _otherSignerValue = 'other-signer';

  static final supportedDevices = List<SignerDeviceEntity>.unmodifiable(
    SignerDeviceEntity.values.where(
      (device) => device.supportsComplexTaprootRegistration,
    ),
  );

  final SignerDeviceEntity? device;
  final ValueChanged<SignerDeviceEntity> onDeviceChanged;
  final String value;
  final ValueChanged<String> onChanged;
  final Future<void> Function(SignerDeviceEntity) onAcquire;
  final Future<void> Function()? onScan;
  final bool usesOtherSigner;
  final VoidCallback? onOtherSignerSelected;
  final bool allowOtherSigner;

  const BullVaultSignerInput({
    super.key,
    required this.device,
    required this.onDeviceChanged,
    required this.value,
    required this.onChanged,
    required this.onAcquire,
    this.onScan,
    this.usesOtherSigner = false,
    this.onOtherSignerSelected,
    this.allowOtherSigner = true,
  }) : assert(!usesOtherSigner || allowOtherSigner),
       assert(!allowOtherSigner || onOtherSignerSelected != null),
       assert(!allowOtherSigner || onScan != null);

  @override
  Widget build(BuildContext context) {
    final selectedValue = usesOtherSigner
        ? _otherSignerValue
        : device == null
        ? null
        : _deviceValue(device!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BBDropdown<String>(
          key: ValueKey(selectedValue),
          value: selectedValue,
          hint: Text(context.loc.bullVaultChooseDevice),
          items: [
            for (final option in supportedDevices)
              DropdownMenuItem(
                value: _deviceValue(option),
                child: Text(option.displayName),
              ),
            if (allowOtherSigner)
              DropdownMenuItem(
                value: _otherSignerValue,
                child: Text(context.loc.bullVaultUseOtherSigner),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            if (value == _otherSignerValue) {
              onOtherSignerSelected!();
              return;
            }
            onDeviceChanged(
              supportedDevices.singleWhere(
                (device) => _deviceValue(device) == value,
              ),
            );
          },
        ),
        const Gap(16),
        if (usesOtherSigner) ...[
          InfoCard(
            description: context.loc.bullVaultGenericSignerWarning,
            tagColor: context.appColors.error,
            bgColor: context.appColors.errorContainer,
          ),
          const Gap(12),
          Text(
            context.loc.bullVaultPublicKeyLabel,
            style: context.font.titleMedium,
          ),
          const Gap(8),
          BullPasteInput(
            text: value,
            hint: context.loc.bullVaultPublicKeyHint,
            onChanged: onChanged,
            onScan: onScan,
            maxLines: 4,
          ),
        ] else if (device case final selectedDevice?) ...[
          if (value.isNotEmpty) ...[
            InfoCard(
              description: context.loc.bullVaultDeviceKeyLoaded(
                selectedDevice.displayName,
              ),
              tagColor: context.appColors.secondary,
              bgColor: context.appColors.onSecondary,
            ),
            const Gap(12),
          ],
          BBButton.big(
            label: value.isEmpty
                ? context.loc.bullVaultGetKeyFromDevice(
                    selectedDevice.displayName,
                  )
                : context.loc.bullVaultReplaceDeviceKey,
            onPressed: () => onAcquire(selectedDevice),
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
            outlined: true,
            borderColor: context.appColors.secondary,
          ),
        ],
      ],
    );
  }

  static String _deviceValue(SignerDeviceEntity device) =>
      'device-${device.name}';
}
