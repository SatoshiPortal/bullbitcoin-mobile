import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/nfc_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/import_coldcard/instructions_bottom_sheet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_router.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class ImportColdcardPage extends StatelessWidget {
  static const _supportedDevices = {
    SignerDeviceEntity.coldcardQ,
    SignerDeviceEntity.coldcardMk4,
  };

  final SignerDeviceEntity signerDevice;

  factory ImportColdcardPage({
    Key? key,
    required SignerDeviceEntity signerDevice,
  }) {
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
    try {
      final watchOnlyWallet = await WatchOnlyWalletEntity.parse(
        payload,
        signerDevice: signerDevice,
      );

      if (!context.mounted) return;
      context.replaceNamed(
        ImportWatchOnlyWalletRoutes.import.name,
        extra: watchOnlyWallet,
      );
    } catch (e) {
      log.warning(
        'Failed to parse Coldcard wallet data received via NFC',
        error: e,
      );
      if (!context.mounted) return;
      SnackBarUtils.showSnackBar(
        context,
        context.loc.importColdcardInvalidWalletData,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceName = signerDevice.displayName;
    final illustrationPath = Assets.misc.qRPlaceholder.path;

    return BullPage(
      topBar: BullTopBar(
        title: context.loc.importColdcardConnectTitle(deviceName),
        onBack: context.pop,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: Device.screen.width * 0.05),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            BullText(
              context.loc.importColdcardConnectDescription(deviceName),
              style: Theme.of(context).textTheme.bodyLarge,
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
                if (signerDevice == SignerDeviceEntity.coldcardQ) ...[
                  BullButton.secondary(
                    label: context.loc.importColdcardButtonOpenCamera,
                    onPressed: () => context.pushNamed(
                      ImportWatchOnlyWalletRoutes.scan.name,
                      extra: signerDevice,
                    ),
                  ),
                  Gap(Device.screen.height * 0.02),
                ],
                BullButton.secondary(
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
                  label: context.loc.importColdcardButtonInstructions,
                  onPressed: () {
                    if (signerDevice == SignerDeviceEntity.coldcardQ) {
                      ColdcardQInstructionsBottomSheet.show(context);
                    } else {
                      ColdcardMk4InstructionsBottomSheet.show(context);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
