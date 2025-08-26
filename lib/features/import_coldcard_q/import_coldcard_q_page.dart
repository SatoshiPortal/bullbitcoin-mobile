import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/import_coldcard_q/instructions_bottom_sheet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class ImportColdcardQPage extends StatelessWidget {
  const ImportColdcardQPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colour.secondaryFixedDim,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: TopBar(title: 'Connect Coldcard Q', onBack: () => context.pop()),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const Gap(32),
            BBText(
              'Import the wallet descriptor QR code from your Coldcard Q',
              style: context.font.bodyLarge,
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
                  label: 'Open the camera',
                  onPressed:
                      () => context.pushNamed(
                        ImportWatchOnlyWalletRoutes.scan.name,
                        extra: SignerDeviceEntity.coldcardQ,
                      ),
                  bgColor: context.colour.onSecondary,
                  textColor: context.colour.secondary,
                  outlined: true,
                ),

                const Gap(16),
                BBButton.small(
                  label: 'Instructions',
                  onPressed: () => InstructionsBottomSheet.show(context),
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
