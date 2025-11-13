import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/import_qr_device/device_instructions_bottom_sheet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ImportQrDevicePage extends StatelessWidget {
  final SignerDeviceEntity device;
  final String deviceName;
  final String instructionsTitle;
  final List<String> instructions;

  const ImportQrDevicePage({
    super.key,
    required this.device,
    required this.deviceName,
    required this.instructionsTitle,
    required this.instructions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.importQrDeviceTitle(deviceName))),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const Gap(32),
            BBText(
              context.loc.importQrDeviceScanPrompt(deviceName),
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
              maxLines: 2,
            ),

            const Gap(48),
            Image.asset(
              Assets.misc.qRPlaceholder.path,
              height: 200,
              width: 200,
            ),
            const Gap(48),
            Column(
              children: [
                BBButton.small(
                  label: context.loc.importQrDeviceButtonOpenCamera,
                  onPressed:
                      () => context.pushNamed(
                        ImportWatchOnlyWalletRoutes.scan.name,
                        extra: device,
                      ),
                  bgColor: Theme.of(context).colorScheme.onSecondary,
                  textColor: Theme.of(context).colorScheme.secondary,
                  outlined: true,
                ),

                const Gap(16),
                BBButton.small(
                  label: context.loc.importQrDeviceButtonInstructions,
                  onPressed:
                      () => DeviceInstructionsBottomSheet.show(
                        context,
                        title: instructionsTitle,
                        instructions: instructions,
                      ),
                  bgColor: Theme.of(context).colorScheme.onSecondary,
                  textColor: Theme.of(context).colorScheme.secondary,
                  outlined: true,
                ),
                const Gap(16),
              ],
            ),
            const Gap(48),
          ],
        ),
      ),
    );
  }
}
