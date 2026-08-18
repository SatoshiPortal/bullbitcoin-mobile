import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/import_qr_device/device_instructions_bottom_sheet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart';
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
    return BullPage(
      topBar: BullTopBar(
        title: context.loc.importQrDeviceTitle(deviceName),
        onBack: context.pop,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: Device.screen.width * 0.05),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            BullText(
              context.loc.importQrDeviceScanPrompt(deviceName),
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: .center,
              maxLines: 2,
            ),

            if (device == SignerDeviceEntity.jade) ...[
              Gap(Device.screen.height * 0.03),
              BullInfoCard(
                description: context.loc.importQrDeviceJadeFirmwareWarning,
                tagColor: context.bull.warning,
                bgColor: context.bull.warningContainer,
              ),
            ],

            Gap(Device.screen.height * 0.05),
            Image.asset(
              Assets.misc.qRPlaceholder.path,
              height: 200,
              width: 200,
            ),
            Gap(Device.screen.height * 0.05),
            Column(
              children: [
                BullButton.secondary(
                  label: context.loc.importQrDeviceButtonOpenCamera,
                  onPressed: () => context.pushNamed(
                    ImportWatchOnlyWalletRoutes.scan.name,
                    extra: device,
                  ),
                ),

                Gap(Device.screen.height * 0.02),
                BullButton.secondary(
                  label: context.loc.importQrDeviceButtonInstructions,
                  onPressed: () => DeviceInstructionsBottomSheet.show(
                    context,
                    title: instructionsTitle,
                    instructions: instructions,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
