import 'package:signers/signers.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/scanning/public/nfc_scanning.dart';
import 'package:wallet_import/wallet_import.dart';
import 'package:primitives/primitives.dart' show Ok;
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
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

  factory ImportColdcardPage({Key? key, required SignerDevice signerDevice}) {
    if (!_supportedDevices.contains(signerDevice)) {
      throw ArgumentError.value(
        signerDevice,
        'signerDevice',
        'Only Coldcard Q and Coldcard Mk4 are supported',
      );
    }

    return ImportColdcardPage._(key: key, signerDevice: signerDevice);
  }

  const ImportColdcardPage._({super.key, required this.signerDevice});

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
    final illustrationPath = Assets.misc.qRPlaceholder.path;

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
            Image.asset(
              illustrationPath, // TODO: Mk4 needs a different illustration.
              height: 200,
              width: 200,
            ),
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
