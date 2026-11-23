import 'package:signers/signers.dart';
import 'package:wallet_import/src/presentation/import_l10n.dart';
import 'package:wallet_import/src/import_navigation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButtonSize,
        BullButton,
        BullInfoCard,
        BullInstructionsSheet,
        BullText,
        Gap,
        BullTypographyX,
        BullThemeX;

class ImportQrDevicePage extends StatelessWidget {
  final SignerDevice device;
  final ImageProvider<Object> illustration;
  final String deviceName;
  final String instructionsTitle;
  final List<String> instructions;

  const ImportQrDevicePage({
    super.key,
    required this.device,
    required this.illustration,
    required this.deviceName,
    required this.instructionsTitle,
    required this.instructions,
  });

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.importQrDeviceTitle(deviceName))),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: screen.width * 0.05),
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
              Gap(screen.height * 0.03),
              BullInfoCard(
                description: context.loc.importQrDeviceJadeFirmwareWarning,
                tagColor: context.bull.warning,
                bgColor: context.bull.warningContainer,
              ),
            ],

            Gap(screen.height * 0.05),
            Image(image: illustration, height: 200, width: 200),
            Gap(screen.height * 0.05),
            Column(
              children: [
                BullButton.secondary(
                  size: BullButtonSize.small,
                  label: context.loc.importQrDeviceButtonOpenCamera,
                  onPressed: () => ImportNavigation.openWatchOnlyScanner(
                    context,
                    device: device,
                  ),
                ),

                Gap(screen.height * 0.02),
                BullButton.secondary(
                  size: BullButtonSize.small,
                  label: context.loc.importQrDeviceButtonInstructions,
                  onPressed: () => BullInstructionsSheet.show(
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
