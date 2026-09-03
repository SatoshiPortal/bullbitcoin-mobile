import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_policy_registration_name.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bull_ui/bull_ui.dart' show BullInputText, Gap;
import 'package:flutter/material.dart';

Future<String?> promptBullVaultRegistrationName(
  BuildContext context, {
  required WalletSigner signer,
  required String fallbackName,
}) {
  final device = signer.signerDevice;
  if (device == null) return Future.value(null);
  return showDialog<String>(
    context: context,
    builder: (_) => _RegistrationNameDialog(
      initialValue: WalletPolicyRegistrationName.suggestion(
        signer.registrationName ?? fallbackName,
        device,
      ),
      device: device,
    ),
  );
}

final class _RegistrationNameDialog extends StatefulWidget {
  final String initialValue;
  final SignerDeviceEntity device;

  const _RegistrationNameDialog({
    required this.initialValue,
    required this.device,
  });

  @override
  State<_RegistrationNameDialog> createState() =>
      _RegistrationNameDialogState();
}

final class _RegistrationNameDialogState
    extends State<_RegistrationNameDialog> {
  late var _value = widget.initialValue;
  var _invalid = false;

  void _submit() {
    try {
      Navigator.of(
        context,
      ).pop(WalletPolicyRegistrationName.validate(_value, widget.device));
    } on ArgumentError {
      setState(() => _invalid = true);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.loc.bullVaultRegistrationNameTitle),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.loc.bullVaultRegistrationNameDescription),
        const Gap(16),
        Text(
          context.loc.bullVaultRegistrationNameLabel,
          style: context.font.titleSmall,
        ),
        const Gap(8),
        BullInputText(
          value: _value,
          onChanged: (value) => setState(() {
            _value = value;
            _invalid = false;
          }),
          maxLength: WalletPolicyRegistrationName.maxLengthFor(widget.device),
          maxLines: 1,
        ),
        if (_invalid) ...[
          const Gap(8),
          Text(
            context.loc.bullVaultRegistrationNameInvalid,
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.error,
            ),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.loc.cancel),
      ),
      TextButton(onPressed: _submit, child: Text(context.loc.continueButton)),
    ],
  );
}
