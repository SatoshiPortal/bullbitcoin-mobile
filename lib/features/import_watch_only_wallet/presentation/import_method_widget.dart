import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class ImportMethodWidget extends StatelessWidget {
  const ImportMethodWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Gap(12),
            BBButton.small(
              label: context.loc.importWatchOnlyScanQR,
              onPressed:
                  () => context.replaceNamed(
                    ImportWatchOnlyWalletRoutes.scan.name,
                  ),
              iconData: Icons.qr_code_scanner,
              bgColor: context.colour.onSecondary,
              textColor: context.colour.secondary,
              outlined: true,
            ),

            const Gap(12),
          ],
        ),

        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              BBButton.small(
                label: context.loc.importWatchOnlyBuyDevice,
                onPressed:
                    () => launchUrl(
                      Uri.parse('https://store.coinkite.com/promo/BULLBITCOIN'),
                    ),
                iconData: Icons.shopping_cart,
                bgColor: context.colour.onSecondary,
                textColor: context.colour.secondary,
                outlined: true,
              ),
              const Gap(12),
              BBButton.small(
                label: context.loc.importWatchOnlyWalletGuides,
                onPressed:
                    () => launchUrl(
                      Uri.parse('https://docs.bull.ethicnology.com'),
                    ),
                iconData: Icons.lightbulb_outline,
                bgColor: context.colour.onSecondary,
                textColor: context.colour.secondary,
                outlined: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
