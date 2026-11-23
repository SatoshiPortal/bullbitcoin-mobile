import 'package:signers/signers.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/import_qr_device/device_instructions_bottom_sheet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButtonSize,
        BullButton,
        BullInfoCard,
        BullText,
        Gap,
        BullTypographyX;
import 'package:go_router/go_router.dart';

class ImportQrDevicePage extends StatelessWidget {
  final SignerDevice device;
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
            BullText(
              context.loc.importQrDeviceScanPrompt(deviceName),
              style: context.bullType.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: .center,
              maxLines: 2,
            ),

            if (device == SignerDevice.jade) ...[
              Gap(Device.screen.height * 0.03),
              BullInfoCard(
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
                BullButton.secondary(
                  size: BullButtonSize.small,
                  label: context.loc.importQrDeviceButtonOpenCamera,
                  onPressed: () => context.pushNamed(
                    ImportWatchOnlyWalletRoutes.scan.name,
                    extra: device,
                  ),
                ),

                Gap(Device.screen.height * 0.02),
                BullButton.secondary(
                  size: BullButtonSize.small,
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
