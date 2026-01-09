import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
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
        padding: EdgeInsets.symmetric(horizontal: Device.screen.width * 0.05),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            BBText(
              context.loc.importQrDeviceScanPrompt(deviceName),
              style: context.font.bodyLarge,
              textAlign: .center,
              maxLines: 2,
            ),

            if (device == SignerDeviceEntity.jade) ...[
              Gap(Device.screen.height * 0.03),
              InfoCard(
                description: context.loc.importQrDeviceJadeFirmwareWarning,
                tagColor: context.appColors.warning,
                bgColor: context.appColors.warningContainer,
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
                BBButton.small(
                  label: context.loc.importQrDeviceButtonOpenCamera,
                  onPressed: () => context.pushNamed(
                    ImportWatchOnlyWalletRoutes.scan.name,
                    extra: device,
                  ),
                  bgColor: context.appColors.surface,
                  textColor: context.appColors.text,
                  outlined: true,
                ),

                Gap(Device.screen.height * 0.02),
                BBButton.small(
                  label: context.loc.importQrDeviceButtonInstructions,
                  onPressed: () => DeviceInstructionsBottomSheet.show(
                    context,
                    title: instructionsTitle,
                    instructions: instructions,
                  ),
                  bgColor: context.appColors.surface,
                  textColor: context.appColors.text,
                  outlined: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
