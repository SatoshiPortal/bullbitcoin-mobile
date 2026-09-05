import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/psbt_flow/public/psbt_flow_facade.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';

class PsbtSigningQrScreen extends StatelessWidget {
  final String psbt;

  const PsbtSigningQrScreen({super.key, required this.psbt});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.psbtSigningQrTitle)),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              BullText(
                context.loc.psbtSigningQrDescription,
                style: context.font.bodyMedium,
                color: context.appColors.textMuted,
                textAlign: TextAlign.center,
                maxLines: 3,
              ),
              const Gap(24),
              ShowAnimatedQrWidget(psbt: psbt, qrType: QrType.urqr),
            ],
          ),
        ),
      ),
    ),
  );
}
