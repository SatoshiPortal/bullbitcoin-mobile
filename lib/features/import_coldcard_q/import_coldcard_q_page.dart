import 'package:bb_mobile/core_deprecated/entities/signer_device_entity.dart';
import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/utils/constants.dart';
import 'package:bb_mobile/core_deprecated/widgets/buttons/button.dart';
import 'package:bb_mobile/core_deprecated/widgets/text/text.dart';
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
      appBar: AppBar(title: Text(context.loc.importColdcardTitle)),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: Device.screen.width * 0.05),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            BBText(
              context.loc.importColdcardDescription,
              style: context.font.bodyLarge,
              textAlign: .center,
              maxLines: 2,
            ),

            Gap(Device.screen.height * 0.05),
            Image.asset(
              Assets.misc.qRPlaceholder.path,
              height: 200,
              width: 200,
              color: context.appColors.text,
            ),
            Gap(Device.screen.height * 0.05),
            Column(
              children: [
                BBButton.small(
                  label: context.loc.importColdcardButtonOpenCamera,
                  onPressed:
                      () => context.pushNamed(
                        ImportWatchOnlyWalletRoutes.scan.name,
                        extra: SignerDeviceEntity.coldcardQ,
                      ),
                  bgColor: context.appColors.surface,
                  textColor: context.appColors.text,
                  outlined: true,
                ),

                Gap(Device.screen.height * 0.02),
                BBButton.small(
                  label: context.loc.importColdcardButtonInstructions,
                  onPressed:
                      () => ColdcardQInstructionsBottomSheet.show(context),
                  bgColor: context.appColors.surface,
                  textColor: context.appColors.text,
                  outlined: true,
                ),
                Gap(Device.screen.height * 0.02),
                BBButton.small(
                  label: context.loc.importColdcardButtonPurchase,
                  onPressed:
                      () => launchUrl(
                        Uri.parse(
                          'https://store.coinkite.com/promo/BULLBITCOIN',
                        ),
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
