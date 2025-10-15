import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/nfc_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/import_coldcard/instructions_bottom_sheet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_router.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:satoshifier/satoshifier.dart';
import 'package:url_launcher/url_launcher.dart';

class ImportColdcardPage extends StatelessWidget {
  final SignerDeviceEntity signerDevice;

  const ImportColdcardPage({super.key, required this.signerDevice});

  Future<void> _handleNfcData(String payload, BuildContext context) async {
    final watchOnly = await Satoshifier.parse(payload);
    if (watchOnly is WatchOnlyDescriptor) {
      final watchOnlyDescriptor = WatchOnlyWalletEntity.descriptor(
        watchOnlyDescriptor: watchOnly,
        signerDevice: signerDevice,
      );
      if (!context.mounted) return;
      context.replaceNamed(
        ImportWatchOnlyWalletRoutes.import.name,
        extra: watchOnlyDescriptor,
      );
    }

    if (watchOnly is WatchOnlyXpub) {
      final watchOnlyXpub = WatchOnlyWalletEntity.xpub(
        watchOnlyXpub: watchOnly,
      );
      if (!context.mounted) return;
      context.replaceNamed(
        ImportWatchOnlyWalletRoutes.import.name,
        extra: watchOnlyXpub,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Connect ${signerDevice.displayName}')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const Gap(32),
            BBText(
              'Import the wallet descriptor from your ${signerDevice.displayName}',
              style: context.font.bodyLarge,
              textAlign: TextAlign.center,
              maxLines: 2,
            ),

            const Gap(48),
            Image.asset(
              Assets.misc.qRPlaceholder.path, // TODO: Mk4 needs a different icon
              height: 200,
              width: 200,
            ),
            const Gap(48),
            Column(
              children: [
                if (signerDevice == SignerDeviceEntity.coldcardQ) ...[
                  BBButton.small(
                    label: 'Open the camera',
                    onPressed:
                        () => context.pushNamed(
                          ImportWatchOnlyWalletRoutes.scan.name,
                          extra: signerDevice,
                        ),
                    bgColor: context.colour.onSecondary,
                    textColor: context.colour.secondary,
                    outlined: true,
                  ),
                  const Gap(16),
                ],
                BBButton.small(
                  label: 'Scan via NFC',
                  onPressed:
                      () => NfcBottomSheet.showReadNfc(
                        context: context,
                        title:
                            'Tap your ${signerDevice.displayName} to import wallet descriptor via NFC',
                        onDataReceived:
                            (payload) => _handleNfcData(payload, context),
                      ),
                  bgColor: context.colour.onSecondary,
                  textColor: context.colour.secondary,
                  outlined: true,
                ),
                const Gap(16),
                BBButton.small(
                  label: 'Instructions',
                  onPressed: () {
                    if (signerDevice == SignerDeviceEntity.coldcardQ) {
                      ColdcardQInstructionsBottomSheet.show(context);
                    } else {
                      ColdcardMk4InstructionsBottomSheet.show(context);
                    }
                  },
                  bgColor: context.colour.onSecondary,
                  textColor: context.colour.secondary,
                  outlined: true,
                ),
                const Gap(16),
                BBButton.small(
                  label: 'Purchase device',
                  onPressed:
                      () => launchUrl(
                        Uri.parse(
                          'https://store.coinkite.com/promo/BULLBITCOIN',
                        ),
                      ),
                  bgColor: context.colour.onSecondary,
                  textColor: context.colour.secondary,
                  outlined: true,
                ),
              ],
            ),
            const Gap(48),
          ],
        ),
      ),
    );
  }
}
