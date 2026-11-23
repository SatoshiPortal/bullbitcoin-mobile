import 'package:signers/signers.dart';
import 'package:wallet_import/src/presentation/import_l10n.dart';
import 'package:bull_ui/app_theme.dart' show Device;
import 'package:bull_logger/bull_logger.dart';
import 'package:scanning/scanning.dart';
import 'package:wallet_import/src/import_navigation.dart';
import 'package:wallet_import/src/domain/watch_only_input.dart';
import 'package:primitives/primitives.dart' show Ok;
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButtonSize,
        BullButton,
        BullSnackBar,
        BullText,
        Gap,
        BullTypographyX;

class ImportColdcardPage extends StatelessWidget {
  static const _supportedDevices = {
    SignerDevice.coldcardQ,
    SignerDevice.coldcardMk4,
  };

  final SignerDevice signerDevice;
  final ImageProvider<Object> qrIllustration;

  factory ImportColdcardPage({
    Key? key,
    required SignerDevice signerDevice,
    required ImageProvider<Object> qrIllustration,
  }) {
    if (!_supportedDevices.contains(signerDevice)) {
      throw ArgumentError.value(
        signerDevice,
        'signerDevice',
        'Only Coldcard Q and Coldcard Mk4 are supported',
      );
    }

    return ImportColdcardPage._(
      key: key,
      signerDevice: signerDevice,
      qrIllustration: qrIllustration,
    );
  }

  const ImportColdcardPage._({
    super.key,
    required this.signerDevice,
    required this.qrIllustration,
  });

  Future<void> _handleNfcData(BuildContext context, String payload) async {
    final wallet = await WatchOnlyInput.parse(
      payload,
      signerDevice: signerDevice,
    );
    if (!context.mounted) return;
    if (wallet case Ok(:final value)) {
      ImportNavigation.replaceWithWatchOnly(context, value);
    } else {
      log.warning('Failed to parse Coldcard wallet data received via NFC');
      BullSnackBar.show(
        context,
        message: context.loc.importColdcardInvalidWalletData,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceName = signerDevice.displayName;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.importColdcardConnectTitle(deviceName)),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: Device.screen.width * 0.05),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            BullText(
              context.loc.importColdcardConnectDescription(deviceName),
              style: context.bullType.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: .center,
              maxLines: 2,
            ),

            Gap(Device.screen.height * 0.05),
            Image(image: qrIllustration, height: 200, width: 200),
            Gap(Device.screen.height * 0.05),
            Column(
              children: [
                if (signerDevice == SignerDevice.coldcardQ) ...[
                  BullButton.secondary(
                    size: BullButtonSize.small,
                    label: context.loc.importColdcardButtonOpenCamera,
                    onPressed: () => ImportNavigation.openWatchOnlyScanner(
                      context,
                      device: signerDevice,
                    ),
                  ),
                  Gap(Device.screen.height * 0.02),
                ],
                BullButton.secondary(
                  size: BullButtonSize.small,
                  label: context.loc.scanNfcButton,
                  onPressed: () => NfcBottomSheet.showReadNfc(
                    context: context,
                    title: context.loc.importColdcardScanNfcSheetTitle(
                      deviceName,
                    ),
                    onDataReceived: (payload) =>
                        _handleNfcData(context, payload),
                  ),
                ),
                Gap(Device.screen.height * 0.02),
                BullButton.secondary(
                  size: BullButtonSize.small,
                  label: context.loc.importColdcardButtonInstructions,
                  onPressed: () => ImportNavigation.showColdcardInstructions(
                    context,
                    signerDevice,
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
